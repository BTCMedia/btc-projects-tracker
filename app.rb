require 'rubygems'
require 'bundler/setup'

Bundler.require(:default)
Dotenv.load

require 'sinatra/reloader' if development?

Repo = Struct.new(:node_id, :full_name, :name, :html_url, :description, :homepage, :forks_count, :watchers_count, :subscribers_count)
Release = Struct.new(:repo, :node_id, :name, :tag_name, :body, :html_url, :created_at, :published_at)

before '/*/' do
  redirect request.path_info.chomp('/')
end

get '/' do
	send_file "./views/index.html"
end

get '/rss' do
	send_file './views/feed.xml'
end

# get '/html' do
# 	@markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
# 	@repo_name = ENV['GITHUB_REPO_NAME']

# 	client = Octokit::Client.new(:access_token => ENV['GITHUB_API_TOKEN'])

# 	repositories = JSON.parse(File.read('repositories.json'))

# 	repos = repositories.collect {|p| r = client.repository(p); Repo.new(r.node_id, r.full_name, r.name, r.html_url, r.description, r.homepage, r.forks_count, r.watchers_count, r.subscribers_count)}.sort_by {|i| i.watchers_count}.reverse

# 	# Take the first 100 repos ordered by release date
# 	releases = repos.collect do |repo|
# 		rs = client.releases(repo.full_name)
# 		releases = rs.collect {|p| Release.new(repo, p.node_id, p.name, p.tag_name, p.body, p.html_url, p.created_at, p.published_at)}
# 	end.flatten.sort_by {|i| i.published_at}.reverse[0...100]

# 	@repos = repos
# 	@releases = releases

# 	erb :index
# end

