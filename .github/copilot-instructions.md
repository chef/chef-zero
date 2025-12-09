# Chef Zero - GitHub Copilot Development Instructions

## Repository Overview

Chef Zero is an in-memory Chef server implementation designed for testing and development purposes. It provides a lightweight, fast alternative to a full Chef server for local development and testing scenarios.

## Repository Structure

```
chef-zero/
├── bin/
│   └── chef-zero                    # CLI executable
├── lib/
│   ├── chef_zero.rb                 # Main entry point
│   └── chef_zero/
│       ├── version.rb               # Version management
│       ├── server.rb                # Core server implementation
│       ├── rest_*.rb               # REST API components
│       ├── chef_data/              # Chef data handling
│       │   ├── acl_path.rb
│       │   ├── cookbook_data.rb
│       │   ├── data_normalizer.rb
│       │   └── default_creator.rb
│       ├── data_store/             # Data storage implementations
│       │   ├── memory_store*.rb    # In-memory storage
│       │   ├── raw_file_store.rb   # File-based storage
│       │   └── interface_*.rb      # Storage interfaces
│       ├── endpoints/              # API endpoint implementations
│       │   ├── *_endpoint.rb       # Various Chef API endpoints
│       │   └── cookbooks_base.rb   # Cookbook handling base
│       └── solr/                   # Search functionality
│           └── solr_doc.rb
├── spec/                           # RSpec test suite
│   ├── *_spec.rb                  # Unit tests
│   ├── run_oc_pedant.rb           # Integration test runner
│   └── support/                   # Test support files
├── playground/                     # Test data and examples
│   ├── cookbooks/
│   ├── data_bags/
│   ├── environments/
│   └── nodes/
├── .expeditor/                     # Build and release automation
├── .github/                        # GitHub workflows and templates
└── Rakefile                       # Build tasks and test runners
```

## Development Workflow

### 1. Jira Integration (MCP Server)

When a Jira ID is provided, use the **atlassian-mcp-server** to:

1. Fetch issue details using `mcp_atlassian-mcp_getJiraIssue`
2. Read the story description and acceptance criteria
3. Understand requirements before implementation
4. Update Jira with progress using `mcp_atlassian-mcp_addCommentToJiraIssue`

### 2. Implementation Process

#### Step-by-Step Workflow

1. **Analysis Phase**
   - Fetch and analyze Jira issue details
   - Review existing code and tests
   - Identify files that need modification
   - Plan implementation approach

2. **Development Phase**
   - Create feature branch named after Jira ID
   - Implement changes following Ruby/Chef conventions
   - Ensure code follows existing patterns and styles
   - Add comprehensive error handling

3. **Testing Phase**
   - Write unit tests for new functionality
   - Ensure test coverage remains > 80%
   - Run existing test suite to prevent regressions
   - Test with both RSpec and oc-pedant integration tests

4. **Documentation Phase**
   - Update relevant documentation
   - Add code comments where necessary
   - Update CHANGELOG.md if applicable

5. **Review and PR Phase**
   - Create pull request with proper description
   - Link to Jira issue
   - Ensure all CI checks pass

### 3. Testing Requirements

**Mandatory Testing Standards:**

- Minimum 80% test coverage required
- Unit tests for all new functionality using RSpec
- Integration tests using oc-pedant when applicable
- Test both success and error scenarios
- Mock external dependencies appropriately

**Test Commands:**

```bash
# Run unit tests
rake spec

# Run integration tests
rake pedant

# Run style checks
rake style

# Run all tests with coverage
COVERAGE=true rake spec
```

### 4. DCO Compliance Requirements

**All commits MUST be signed off** according to the Developer Certificate of Origin (DCO):

- Add `-s` flag to all commits: `git commit -s -m "Your commit message"`
- Commits without proper sign-off will be rejected
- Use your real name and email address
- Each commit must include: `Signed-off-by: Your Name <your.email@example.com>`

### 5. Branch Management and PR Creation

When prompted to create a PR:

```bash
# Create and switch to feature branch (use Jira ID as branch name)
gh repo clone chef/chef-zero  # if not already cloned
cd chef-zero
git checkout -b JIRA-123  # Replace with actual Jira ID

# Make your changes and commit with DCO sign-off
git add .
git commit -s -m "feat: implement feature described in JIRA-123"

# Push branch and create PR
git push origin JIRA-123
gh pr create --title "feat: Brief description of changes" \
  --body "$(cat <<EOF
<h2>Summary</h2>
<p>Brief description of changes made</p>

<h2>Changes Made</h2>
<ul>
<li>Change 1</li>
<li>Change 2</li>
</ul>

<h2>Testing</h2>
<ul>
<li>Unit tests added/updated</li>
<li>Integration tests passing</li>
<li>Code coverage maintained >80%</li>
</ul>

<h2>Related Issues</h2>
<p>Fixes: JIRA-123</p>
EOF
)"
```

### 6. Build System Integration

**Expeditor Build System:**

- Automatic version bumping on merge
- Changelog generation
- Gem publishing to RubyGems
- Available labels for version control:
  - `Expeditor: Bump Version Major`
  - `Expeditor: Bump Version Minor`
  - `Expeditor: Skip Version Bump`
  - `Expeditor: Skip Changelog`

**GitHub Workflows:**

- `ci-main-pull-request-checks.yml`: Main CI pipeline
- `unit-test.yml`: Unit test execution
- `lint.yml`: Code style checking
- `sonarqube.yml`: Code quality analysis

### 7. Repository-Specific GitHub Labels

**Aspect Labels:**

- `Aspect: Documentation`: Documentation-related changes
- `Aspect: Integration`: Integration with other systems
- `Aspect: Packaging`: Distribution and packaging
- `Aspect: Performance`: Performance-related improvements
- `Aspect: Portability`: Cross-platform compatibility
- `Aspect: Search`: Search functionality
- `Aspect: Security`: Security-related changes
- `Aspect: Stability`: Stability improvements
- `Aspect: Testing`: Test-related changes
- `Aspect: UI`: User interface changes
- `Aspect: UX`: User experience improvements

**Platform Labels:**

- `Platform: AWS`, `Platform: Azure`, `Platform: GCP`
- `Platform: Linux`, `Platform: macOS`
- `Platform: Debian-like`, `Platform: RHEL-like`, `Platform: SLES-like`
- `Platform: Docker`

**Special Labels:**

- `dependencies`: Dependency updates
- `oss-standards`: OSS standardization
- `hacktoberfest-accepted`: Hacktoberfest contributions

### 8. Prompt-Based Development

**After each step, provide:**

1. Summary of completed work
2. Current status
3. Next step in the process
4. Remaining steps overview
5. **Ask for confirmation to continue**

Example prompt:

```
✅ Completed: Analysis of Jira issue JIRA-123 and identified required changes
📍 Current: Ready to implement feature in lib/chef_zero/endpoints/
🔜 Next: Create new endpoint class and add routing
📋 Remaining: Implementation → Testing → Documentation → PR Creation

Would you like me to proceed with the implementation phase?
```

### 9. Prohibited Modifications

**DO NOT modify these files without explicit approval:**

- `VERSION` file (managed by Expeditor)
- `.expeditor/config.yml` (build configuration)
- Core gemspec metadata
- License files
- GitHub workflow files (unless specifically requested)

### 10. Code Style and Conventions

**Ruby Style Guidelines:**

- Follow RuboCop/Cookstyle conventions
- Use 2-space indentation
- Maximum 120 characters per line
- Prefer explicit returns in public methods
- Use meaningful variable and method names
- Add appropriate error handling and logging

**Chef Zero Specific Patterns:**

- Inherit from `RestBase` for new endpoints
- Use appropriate HTTP status codes
- Follow existing JSON response formats
- Maintain backward compatibility
- Add proper logging with ChefZero::Log

### 11. Error Handling Standards

```ruby
# Example error handling pattern
begin
  # Operation that might fail
rescue SpecificError => e
  raise RestErrorResponse.new(404, "Resource not found: #{e.message}")
rescue StandardError => e
  ChefZero::Log.error("Unexpected error: #{e.message}")
  raise RestErrorResponse.new(500, "Internal server error")
end
```

### 12. Documentation Requirements

- Update README.md for new features
- Add inline documentation for complex methods
- Update API documentation if endpoints change
- Include usage examples where appropriate
- Document any breaking changes

## Quick Reference Commands

```bash
# Setup development environment
bundle install

# Run tests
rake spec                    # Unit tests
rake pedant                  # Integration tests
rake style                   # Style checks

# Start development server
bin/chef-zero --port 8889

# Create feature branch and PR
git checkout -b JIRA-123
# ... make changes ...
git commit -s -m "feat: description"
git push origin JIRA-123
gh pr create --title "Title" --body "Description with HTML tags"
```

## Contact and Support

- Primary communication via Slack: `#chef-infra-notify`
- Follow Chef Software contribution guidelines
- Ensure DCO compliance for all contributions
- Maintain compatibility with Chef Client versions 11+

## AI-Assisted Development & Compliance

- ✅ Create PR with `ai-assisted` label (if label doesn't exist, create it with description "Work completed with AI assistance following Progress AI policies" and color "9A4DFF")
- ✅ Include "This work was completed with AI assistance following Progress AI policies" in PR description

### Jira Ticket Updates (MANDATORY)

- ✅ **IMMEDIATELY after PR creation**: Update Jira ticket custom field `customfield_11170` ("Does this Work Include AI Assisted Code?") to "Yes"
- ✅ Use atlassian-mcp tools to update the Jira field programmatically
- ✅ **CRITICAL**: Use correct field format: `{"customfield_11170": {"value": "Yes"}}`
- ✅ Verify the field update was successful

### Documentation Requirements

- ✅ Reference AI assistance in commit messages where appropriate
- ✅ Document any AI-generated code patterns or approaches in PR description
- ✅ Maintain transparency about which parts were AI-assisted vs manual implementation

### Workflow Integration

This AI compliance checklist should be integrated into the main development workflow Step 4 (Pull Request Creation):

```
Step 4: Pull Request Creation & AI Compliance
- Step 4.1: Create branch and commit changes WITH SIGNED-OFF COMMITS
- Step 4.2: Push changes to remote
- Step 4.3: Create PR with ai-assisted label
- Step 4.4: IMMEDIATELY update Jira customfield_11170 to "Yes"
- Step 4.5: Verify both PR labels and Jira field are properly set
- Step 4.6: Provide complete summary including AI compliance confirmation
```

- **Never skip Jira field updates** - This is required for Progress AI governance
- **Always verify updates succeeded** - Check response from atlassian-mcp tools
- **Treat as atomic operation** - PR creation and Jira updates should happen together
- **Double-check before final summary** - Confirm all AI compliance items are completed

### Audit Trail

All AI-assisted work must be traceable through:

1. GitHub PR labels (`ai-assisted`)
2. Jira custom field (`customfield_11170` = "Yes")
3. PR descriptions mentioning AI assistance
4. Commit messages where relevant

---

*This document should be updated as the project evolves and new requirements emerge.*
