# Ensure there is a summary for a pull request
fail 'Please provide a summary in the Pull Request description' if github.pr_body.length < 5

# Warn about develop branch
warn("Please target PRs to `develop` branch") if github.branch_for_base != "develop"

# Make it more obvious that a PR is a work in progress and shouldn't be merged yet
warn("PR is classed as Work in Progress") if github.pr_title.include? "[WIP]"

# Warn when there is a big PR
warn("Big PR") if git.lines_of_code > 500

## Let's check if there are any changes in the project folder
has_app_changes = !git.modified_files.grep(/SwiftyStoreKit/).empty?

## Then, we should check if tests are updated
has_test_changes = !git.modified_files.grep(/SwiftyStoreKitTests/).empty?

## Finally, let's combine them and put extra condition
## for changed number of lines of code
if has_app_changes && !has_test_changes && git.lines_of_code > 20
  fail("Tests were not updated", sticky: false)
end
