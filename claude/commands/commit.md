---
name: commit
description: "Generate Conventional Commits 1.0.0 messages with Gitmoji from git diff"
category: utility
complexity: basic
mcp-servers: []
personas: []
---

# /commit - Conventional Commit Message Generator

## Triggers
- Git commit operations requiring message generation
- Staged changes ready for commit (`git diff --staged` has content)
- Need for Conventional Commits 1.0.0 compliant messages
- Commit message generation with Gitmoji support

## Usage
```
/commit [--context "additional context about the changes"]
```

## Behavioral Flow
1. **Check Stage**: Execute `git diff --staged` to check for staged changes
   - If no staged changes: Execute `git status` to check for unstaged changes
   - If unstaged changes exist: Ask user "No staged files found. Stage all changes? (yes/no)"
   - If user confirms: Execute `git add .` and proceed
   - If user declines: Exit with message "Please stage files manually with 'git add' first"
   - If no changes at all: Exit with message "No changes to commit"
2. **Analyze**: Execute `git diff --staged` to examine all staged changes
3. **Classify**: Determine change type(s) based on diff content
4. **Generate**: Create commit message following all specification rules
5. **Format**: Apply proper structure (emoji, type, scope, description, body, footer)
6. **Validate**: Ensure 100-char line limits and format compliance
7. **Display**: Show generated commit message to user for review
8. **Commit**: Execute `git commit` with generated message using heredoc format
9. **Confirm**: Display commit success with short hash

Key behaviors:
- Check for staged changes, prompt to stage if none found
- Follow Conventional Commits 1.0.0 specification precisely
- Include appropriate Gitmoji emoji for each commit type
- Use imperative mood, lowercase, no trailing period in subject
- Maximum 100 characters per line throughout message
- Output in English only
- Display generated message before committing
- Execute git commit with generated message
- For dependency updates: list ONLY direct dependencies from manifest files
- Use Multiple Distinct Changes format ONLY for truly unrelated changes
- No do add co-authored by Claude 

## Conventional Commits 1.0.0 Rules

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" are interpreted per RFC 2119.

1. Commits MUST be prefixed with a type, followed by OPTIONAL scope, OPTIONAL exclamation mark (!), and REQUIRED colon and space
2. Type "feat" MUST be used when adding new features
3. Type "fix" MUST be used when fixing bugs
4. Scope MAY be provided after type (noun in parenthesis, e.g., fix(parser):)
5. Description MUST immediately follow the colon and space
6. Longer commit body MAY be provided after the description (one blank line after)
7. Commit body is free-form and MAY consist of newline-separated paragraphs
8. Footer(s) MAY be provided one blank line after body
9. Footer token MUST use hyphen (-) for whitespace (except BREAKING CHANGE)
10. Footer value MAY contain spaces and newlines
11. Breaking changes MUST be indicated in type/scope prefix OR footer
12. Breaking change footer MUST use "BREAKING CHANGE:" followed by description
13. Breaking change in prefix MUST use exclamation mark (!) before colon, e.g., feat!:
14. Types other than "feat" and "fix" MAY be used
15. Units of information MUST NOT be case sensitive (except BREAKING CHANGE = uppercase)
16. "BREAKING-CHANGE" MUST be synonymous with "BREAKING CHANGE"
17. For dependency updates: body MUST list all updated DIRECT dependencies with versions (from → to). When diff includes both manifest (package.json, Cargo.toml, pyproject.toml) and lockfiles (pnpm-lock.yaml, package-lock.json, Cargo.lock, poetry.lock), ONLY direct dependencies from manifest MUST be listed. Transitive dependencies visible only in lockfiles MUST NOT be included.

## Output Format

### Single Type Changes
```
<emoji> <type>(<scope>): <description>
<BLANK LINE>
[optional <body>]
<BLANK LINE>
[optional <footer(s)>]
```

### Multiple Distinct Changes

Use ONLY when changes address SEPARATE, UNRELATED concerns:

```
<emoji> <type>(<scope>): <description>
<BLANK LINE>
[optional <body>]
<BLANK LINE>
[optional <footer(s)>]
<BLANK LINE>
<BLANK LINE>
<emoji> <type>(<scope>): <description>
<BLANK LINE>
[optional <body>]
<BLANK LINE>
[optional <footer(s)>]
```

**Use Multiple format when:**
- ✅ Bug fix in auth + New feature in payment + Update README
- ✅ Fix broken form + Add API endpoint + Refactor database schema
- ✅ Update dependency + Fix unrelated bug + Add documentation

**Do NOT use Multiple format when:**
- ❌ All changes serve one purpose (e.g., "refactor code style" in 3 files)
- ❌ Changes are related (e.g., "add user profile" affecting multiple files)
- ❌ Same type of work in multiple areas (e.g., "fix validation bugs in auth, payments")
- ❌ Related file changes (e.g., package.json + pnpm-lock.yaml for dependencies)

**Decision rule**: Can changes be described under ONE logical purpose? If YES → Single format. If NO → Multiple format.

## Type Reference

| Type     | Emoji | Description                                           | Example Scopes            |
| -------- | ----- | ----------------------------------------------------- | ------------------------- |
| build    | 🏗️    | Build system or external dependency changes           | gulp, npm, webpack        |
| chore    | 🔧    | Other changes not modifying src or test files         | scripts, config           |
| ci       | 👷    | CI configuration and script changes                   | github-actions, travis    |
| docs     | 📝    | Documentation only changes                            | README, API               |
| feat     | ✨    | New feature                                           | user, payment, gallery    |
| fix      | 🐛    | Bug fix                                               | auth, data, validation    |
| perf     | ⚡️   | Performance improvement                               | query, cache, render      |
| refactor | ♻️    | Code change that neither fixes bug nor adds feature   | utils, helpers, structure |
| revert   | ⏪️   | Reverts a previous commit                             | any                       |
| style    | 💄    | Code style changes (whitespace, formatting, etc)      | formatting, prettier      |
| test     | ✅    | Adding or correcting tests                            | unit, e2e, integration    |
| i18n     | 🌐    | Internationalization                                  | locale, translation       |

### Type Selection Guidelines

- **build**: Changes to build configuration, build scripts, or build-time dependencies
- **chore**: Routine tasks, maintenance, config updates not affecting src/test code
- **ci**: Continuous integration/deployment configuration changes
- **docs**: Documentation updates, comments, README files, API docs
- **feat**: New functionality, new components, new user-facing features
- **fix**: Bug corrections, issue resolutions, error fixes
- **perf**: Performance optimizations, speed improvements, resource efficiency
- **refactor**: Code restructuring without changing external behavior
- **revert**: Undoing previous commits
- **style**: Code formatting, style guide compliance, whitespace fixes
- **test**: Test additions, test corrections, test infrastructure
- **i18n**: Translation files, locale changes, internationalization support

## Writing Rules

### Subject Line
Format: `<emoji> <type>[optional (<scope>)]: <description>`

- **Scope**: Include when change affects specific component/module/area (e.g., `auth`, `api`, `database`, `infra`)
- Omit scope when change affects entire project or multiple unrelated areas
- **Imperative mood**: "add feature" not "added feature" or "adds feature"
- **No capitalization**: Lowercase description
- **No period**: No trailing period at end
- **Maximum 100 characters**: Including emoji, type, scope, and all spaces
- **English only**: All text must be in English

**When to include scope:**
- Change affects specific, identifiable component
- Scope adds clarity about what part changed
- Scope provided in additional context
- Scope clear from file paths

**When to omit scope:**
- Change affects entire project
- Multiple unrelated areas affected
- No single scope accurately describes all changes
- Type and description are sufficient

### Body
- **Bullet points**: Use `-` for bullet points
- **Maximum 100 characters per line**: Including spaces
- **Line breaks**: For bullets exceeding 100 chars, use line breaks without adding extra bullets
- **Content**: Explain WHAT and WHY using ONLY factual, verifiable information from diff
- **Objectivity**: Be precise - describe EXACTLY what changed without subjective interpretations
- **Avoid vagueness**: Don't use "for clarity", "for consistency", "improve readability" unless diff explicitly shows formatting/style changes
- **Reasoning**: ONLY include "why" when:
  - Provided in additional context
  - Clearly evident from code context
  - Objectively verifiable from diff itself
- **Omit if self-explanatory**: Skip body if subject line is sufficient and no additional context provided
- **English only**: All text must be in English

### Footer
Format: `<token>: <value>`

- **Maximum 100 characters per line**
- **Common footers**:
  - `BREAKING CHANGE: <description>` - Non-backward-compatible changes
  - `Fixes #123` / `Closes #456` / `Resolves #789` - Issue/PR closure
  - `Related to #101` / `References #202` - Related issues/PRs
  - `Co-authored-by: Name <email>` - Multiple contributors
  - `Reviewed-by: Name <email>` - Reviewer acknowledgment
  - `Signed-off-by: Name <email>` - DCO compliance
  - `See also #321` - Related references

## Tool Coordination

- **Bash**: Execute `git diff --staged` to retrieve staged changes
- **Bash**: Execute `git status` to understand repository state and check for unstaged changes
- **Bash**: Execute `git add .` to stage all changes (only with user confirmation)
- **Bash**: Execute `git commit` with heredoc format to preserve multi-line messages
- **AskUserQuestion**: Prompt user to stage files if none are staged
- **Grep**: Parse diff output for pattern detection (file types, change patterns)
- **Read**: Analyze file content when needed for context
- **Native Analysis**: Understand change semantics and classify commit type

## Commit Execution Format

Always use heredoc format to preserve message structure:

```bash
git commit -m "$(cat <<'EOF'
<emoji> <type>(<scope>): <description>

- bullet point body content
- additional details

Footer: value
EOF
)"
```

This ensures proper formatting with line breaks, emojis, and special characters.

## Key Patterns

### Dependency Updates
When diff includes manifest files (package.json, Cargo.toml, pyproject.toml, go.mod) AND lockfiles (pnpm-lock.yaml, package-lock.json, Cargo.lock, poetry.lock, go.sum):
- **DO**: List only direct dependencies explicitly updated in manifest
- **DON'T**: List transitive dependencies only in lockfiles
- **Rationale**: Lockfile changes are automatic consequences of direct updates

Example:
```
🔧 chore(deps): update playwright to 1.56.1
```
NOT:
```
🔧 chore(deps): update playwright and 47 transitive dependencies
```

### Very Large Diffs
- Prioritize most significant changes
- Group similar changes (e.g., "update 15 component imports")
- Focus on WHAT and WHY, not exhaustive file-by-file details
- Use Multiple Distinct Changes format if changes naturally group into distinct concerns

### Multiple Areas of Same Type
When same type affects multiple scopes:
- **Option 1**: Omit scope, list affected areas in body
- **Option 2**: Use broader scope encompassing all areas
- **Option 3**: Use Multiple Distinct Changes format with separate entry per scope

### Additional Context Handling
If user provides additional context in `--context` or separate message:
- Consider context carefully when generating message
- Incorporate relevant information into commit body
- Context may clarify WHAT changed, explain WHY, specify scope/type
- Maintain all formatting rules (100-char limit, bullet points)
- Base description of WHAT changed primarily on diff itself
- Use context to supplement or clarify as needed

## Examples

### Example 1: Variable Refactoring
**Input**:
```diff
diff --git a/src/server.ts b/src/server.ts
index ad4db42..f3b18a9 100644
--- a/src/server.ts
+++ b/src/server.ts
@@ -10,7 +10,7 @@ import {
 const app = express();
-const port = 7799;
+const PORT = 7799;

 app.use(express.json());
@@ -34,6 +34,6 @@ app.use((_, res, next) => {
 app.use(PROTECTED_ROUTER_URL, protectedRouter);

-app.listen(port, () => {
-  console.log(`Server listening on port ${port}`);
+app.listen(process.env.PORT || PORT, () => {
+  console.log(`Server listening on port ${PORT}`);
 });
```

**Output**:
```
♻️ refactor(server): use environment variable for port configuration

- rename port variable from lowercase to uppercase (PORT)
- use process.env.PORT with fallback to PORT constant (7799)
```

### Example 2: Config File Extension
**Input**:
```diff
diff --git a/package.json b/package.json
index af76bc0..781d472 100644
--- a/package.json
+++ b/package.json
@@ -11,7 +11,7 @@
     "format": "prettier --write \"**/*.{ts,tsx,md,json,js,jsx}\"",
     "format:check": "prettier --check \"**/*.{ts,tsx,md,json,js,jsx}\"",
     "lint": "eslint . --quiet && tsc --noEmit --skipLibCheck",
-    "lint:staged": "pnpm lint-staged -v --config lint-staged.config.ts",
+    "lint:staged": "pnpm lint-staged -v --config lint-staged.config.mjs",
     "lint:fix": "eslint . --cache --fix",
```

**Output**:
```
🔧 chore: update lint-staged config file extension from ts to mjs

- change lint-staged.config.ts reference to lint-staged.config.mjs in package.json script
```

### Example 3: Multiple Dependencies
**Input**:
```diff
diff --git a/package.json b/package.json
@@ -63,10 +63,10 @@
-    "@tanstack/react-router": "^1.133.15",
-    "@tanstack/router-cli": "^1.133.15",
-    "@tanstack/router-devtools": "^1.133.15",
-    "@tanstack/router-plugin": "^1.133.15",
+    "@tanstack/react-router": "^1.133.21",
+    "@tanstack/router-cli": "^1.133.20",
+    "@tanstack/router-devtools": "^1.133.21",
+    "@tanstack/router-plugin": "^1.133.21",
diff --git a/pnpm-lock.yaml b/pnpm-lock.yaml
[... hundreds of lines of lockfile changes ...]
```

**Output**:
```
🔧 chore(deps): update @tanstack/react-router packages

- @tanstack/react-router: 1.133.15 → 1.133.21
- @tanstack/router-cli: 1.133.15 → 1.133.20
- @tanstack/router-devtools: 1.133.15 → 1.133.21
- @tanstack/router-plugin: 1.133.15 → 1.133.21
```

### Example 4: Single Dependency with Lockfile
**Input**:
```diff
diff --git a/package.json b/package.json
@@ -129,7 +129,7 @@
     "jiti": "^2.4.2",
     "jsdom": "^26.1.0",
     "lint-staged": "^16.1.2",
-    "playwright": "^1.54.1",
+    "playwright": "^1.56.1",
     "postcss": "^8.5.6",
diff --git a/pnpm-lock.yaml b/pnpm-lock.yaml
[... hundreds of lines including playwright-core and transitive deps ...]
```

**Output**:
```
🔧 chore(deps): update playwright to 1.56.1
```

**Explanation**: Only the single direct dependency intentionally updated in package.json is documented. Transitive dependencies (playwright-core, etc.) only visible in lockfile are automatic consequences and are NOT included.

### Example 5: Multiple Distinct Changes
**Input**:
```diff
diff --git a/.gitignore b/.gitignore
[... major gitignore template update ...]
diff --git a/packages/main/src/mainWindow.ts b/packages/main/src/mainWindow.ts
[... remove redundant comment ...]
diff --git a/packages/renderer/src/components/demo/DemoMenu.tsx
[... adjust navbar opacity ...]
diff --git a/packages/shared/src/db/scripts/migration.ts
[... improve console messages ...]
```

**Output**:
```
🔧 chore(gitignore): update to use comprehensive gitignore template

- replace basic macOS section with complete template from toptal.com/developers/gitignore
- add macOS-specific files (DS_Store, Spotlight, Thumbnails, iCloud files)
- add React-specific ignores (node_modules, bower_components, sublime files)
- remove .vscode directory from gitignore to track IDE settings


📝 docs(main): remove redundant comment from mainWindow configuration

- remove "Add this line" comment from backgroundThrottling setting


💄 style(demo): adjust navbar background opacity

- change background opacity from /10 to /15 in DemoMenu navbar


♻️ refactor(db): improve database backup console message

- add "Database" prefix to backup completion and file path messages
```

### Example 6: Full Workflow (No Staged Files)
**Scenario**: User runs `/commit` with no staged files

**Execution Flow**:
```
1. Check: git diff --staged (empty)
2. Check: git status (shows modified files)
3. Prompt: "No staged files found. Stage all changes? (yes/no)"
4. User: "yes"
5. Execute: git add .
6. Execute: git diff --staged (analyze changes)
7. Generate: commit message
8. Display: Show generated message to user
9. Execute: git commit -m "$(cat <<'EOF'
   📝 docs(readme): update installation instructions

   - add prerequisites section
   - update command examples
   EOF
   )"
10. Confirm: "Committed as a1b2c3d"
```

### Example 7: Full Workflow (Files Already Staged)
**Scenario**: User runs `/commit` with files already staged

**Execution Flow**:
```
1. Check: git diff --staged (has changes)
2. Execute: git diff --staged (analyze changes)
3. Generate: commit message
4. Display: Show generated message to user
5. Execute: git commit -m "$(cat <<'EOF'
   🐛 fix(auth): resolve token expiration validation

   - add null check before token expiration comparison
   - return 401 when token is missing or expired
   EOF
   )"
6. Confirm: "Committed as d4e5f6g"
```

## Critical Requirements

1. **Check staging first** - Always check for staged changes before proceeding
2. **Prompt for staging** - If no staged changes, ask user to stage all or exit
3. **Display message before commit** - Show generated message for user review
4. **Write ONLY in English** - All text must be in English language
5. **ALWAYS add emoji** - Emoji must be at the beginning of first line
6. **RESPECT 100-character limit** - Maximum 100 characters per line throughout entire message
7. **NO assumptions** - Use only factual information from diff and provided context
8. **Follow specification precisely** - All 17 Conventional Commits rules must be followed
9. **Dependency rules** - For updates, list ONLY direct dependencies from manifest files
10. **Use heredoc for commit** - Execute git commit with heredoc to preserve formatting

## Boundaries

**Will:**
- Check for staged changes before proceeding
- Prompt user to stage all files if none staged
- Execute `git add .` if user confirms staging
- Analyze staged git changes (`git diff --staged`)
- Generate Conventional Commits 1.0.0 compliant messages
- Include appropriate Gitmoji emoji for each type
- Follow all specification rules precisely
- Handle dependency updates correctly (direct only)
- Support Multiple Distinct Changes format when appropriate
- Incorporate additional context if provided
- Display generated commit message for review
- Execute the commit (`git commit`) with generated message
- Show commit success with short hash

**Will Not:**
- Force stage files without user confirmation
- Commit without displaying message first
- Ask questions about change content (analyze diff directly)
- Include explanations or metadata in commit message
- Wrap commit message in code blocks or special formatting
- List transitive dependencies from lockfiles
- Modify repository configuration beyond staging/committing
- Add content beyond what's in the diff and context
- Skip user confirmation for staging when no files are staged
