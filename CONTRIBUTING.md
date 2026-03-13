# Contributing to migrate-kit

Thanks for your interest. Here's how you can help.

## Ways to Contribute

### Add a Framework

If your framework isn't supported:

1. Add detection logic to `plugin/skills/migrate-kit/scripts/detect-stack.sh`
2. Create a reference file at `plugin/skills/migrate-kit/references/{framework}.md` with breaking changes, codemods, and code examples for each version pair
3. Update the SKILL.md if the framework needs special handling in any phase
4. Test with a real project

### Update Breaking Changes

When a new version of a supported framework is released:

1. Add the new version section to the relevant reference file
2. Include real breaking changes with before/after code examples
3. Note available codemods and required dependency updates
4. List gotchas you've encountered

### Add Custom Codemods

If you've written a codemod (script, regex, AST transform) for a specific migration:

1. Document it in the relevant reference file
2. Include the command to run it and what it changes

### Report Issues

If a migration didn't work correctly:

1. Open an issue with: framework, from version, to version, and what went wrong
2. Include the error message or unexpected behavior
3. If possible, include a minimal reproduction

## Pull Request Guidelines

- One framework or version per PR
- Include real code examples, not theoretical ones
- Test against a real project if possible
- Update CHANGELOG.md

## Questions?

Open an issue.
