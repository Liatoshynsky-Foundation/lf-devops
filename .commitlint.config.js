module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat', // A new feature
        'fix', // A bug fix
        'docs', // Documentation changes
        'refactor', // Code changes that neither fix bugs nor add features
        'perf', // Performance improvements
        'build', // Changes to build system or dependencies
        'ci', // Changes to CI configuration
        'chore', // Other changes that don't modify src or test files
        'revert' // Reverts a previous commit
      ]
    ]
  }
};
