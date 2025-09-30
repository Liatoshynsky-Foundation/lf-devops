import requests
from concurrent.futures import ThreadPoolExecutor, as_completed
import os
from datetime import datetime, timedelta
from tabulate import tabulate

repos = [
    "Liatoshynsky-Foundation/lf-client",
    "Liatoshynsky-Foundation/lf-admin"
]
discord_webhook = os.getenv("DISCORD_WEBHOOK")
github_token = os.getenv("GITHUB_TOKEN")

headers = {
    "Authorization": f"token {github_token}",
    "Accept": "application/vnd.github+json"
}

one_week_ago = datetime.utcnow() - timedelta(days=7)


def fetch_reviews(repo, pr_number):
    url = f"https://api.github.com/repos/{repo}/pulls/{pr_number}/reviews"
    try:
        resp = requests.get(url, headers=headers, timeout=10)
        resp.raise_for_status()
        return pr_number, resp.json()
    except Exception as e:
        print(f"Failed to fetch reviews for PR {pr_number} in {repo}: {e}")
        return pr_number, []


rows = []
header = ["Repository", "User", "CreatedPRs", "ReviewedPRs", "Approved", "Changes", "Commented", "Dismissed"]

for repo in repos:
    print(f"Collecting from {repo}...")
    
    pulls = []
    page = 1
    while True:
        url = f"https://api.github.com/repos/{repo}/pulls?state=all&per_page=100&page={page}"
        resp = requests.get(url, headers=headers, timeout=10)
        data = resp.json()
        if not data:
            break
        pulls.extend(data)
        page += 1

    pulls = [pr for pr in pulls if datetime.strptime(pr['created_at'], "%Y-%m-%dT%H:%M:%SZ") >= one_week_ago]

    
    pr_numbers = [pr['number'] for pr in pulls]
    reviews_dict = {}
    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = [executor.submit(fetch_reviews, repo, num) for num in pr_numbers]
        for future in as_completed(futures):
            pr_num, reviews = future.result()
            reviews_dict[pr_num] = reviews
    
    users = sorted({
            pr['user']['login'] for pr in pulls
        } | {
            r['user']['login']
            for reviews in reviews_dict.values()
            for r in reviews
        })

    for user in users:
        created = sum(1 for pr in pulls if pr['user']['login'] == user)
        approved = changes = commented = dismissed = 0
        reviewed_prs = set()

        for pr in pulls:
            pr_number = pr['number']
            user_reviews = [r for r in reviews_dict.get(pr_number, []) if r['user']['login'] == user]
            if user_reviews:
                reviewed_prs.add(pr_number)
                approved += sum(1 for r in user_reviews if r['state'] == "APPROVED")
                changes += sum(1 for r in user_reviews if r['state'] == "CHANGES_REQUESTED")
                commented += sum(1 for r in user_reviews if r['state'] == "COMMENTED")
                dismissed += sum(1 for r in user_reviews if r['state'] == "DISMISSED")

        rows.append([repo, user, created, len(reviewed_prs), approved, changes, commented, dismissed])


md_content = tabulate(rows, headers=header, tablefmt="github")

files = {
    'file': ('pr_report.md', md_content)
}
resp = requests.post(discord_webhook, files=files)
if resp.status_code == 204:
    print("Markdown file sent to Discord!")
else:
    print(f"Failed to send file: {resp.status_code}, {resp.text}")
