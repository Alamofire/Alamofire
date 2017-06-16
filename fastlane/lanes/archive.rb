desc "Creates a release on GitHub, archives the framework, and uploads it to GitHub's release."
lane :archive do |options|
  token = options[:github_api_token] || ENV["GITHUB_API_TOKEN"]
  token = prompt :text => 'A GitHub API token is required but was not provided. Please provide a valid GitHub API token:' if token.nil?
  UI.verbose "GitHub API Token: #{token}"

  title = options[:github_release_title]
  title = prompt :text => 'A release name is required to create a GitHub release. Please provide a name:' if title.nil?
  UI.verbose "GitHub release name: #{title}"

  tag = options[:github_release_tag]
  tag = prompt :text => 'A release tag is required to create a GitHub release. Please provide a tag:' if tag.nil?
  UI.verbose "GitHub release tag: #{tag}"

  repo_path = options[:archive_repository_path]
  repo_path = prompt :text => 'What is the path of the GitHub repository?' if repo_path.nil?
  UI.verbose "Repository path: #{repo_path}"

  carthage(command: "build", no_skip_current: true)
  carthage(command: "archive", frameworks: 'Alamofire', output: 'build/Alamofire.framework.zip')

  set_github_release(
    api_token: token,
    commitish: git_branch,
    description: "[placeholder]",
    name: title,
    repository_name: repo_path,
    tag_name: tag,
    upload_assets: ['build/Alamofire.framework.zip']
  )
end