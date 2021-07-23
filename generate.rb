require 'rubygems'
require 'bundler/setup'

require 'dotenv'
require 'octokit'
require 'redcarpet'
require 'rss'
require 'json'
require 'erb'

Dotenv.load

Repo = Struct.new(:node_id, :full_name, :name, :html_url, :description, :homepage, :forks_count, :watchers_count, :subscribers_count)
Release = Struct.new(:repo, :node_id, :name, :tag_name, :body, :html_url, :created_at, :published_at)

def generate_xml(repos, releases)
	rss = RSS::Maker.make("atom") do |maker|
	    maker.channel.author = "flip_btc"
	    maker.channel.updated = Time.now.to_s
	    maker.channel.about = "https://release-tracker.b.tc/"
	    maker.channel.title = "Bitcoin Projects Release Tracker"

	    releases.each do |p|
	    	maker.items.new_item do |item|
		      item.link = p.html_url
		      item.title = "#{p.repo.full_name}: #{p.tag_name}"
		      item.summary = p.body
		      item.pubDate = p.created_at
		      item.updated = p.published_at
		    end
	    end
	end

	#File.write('./views/feed.xml', rss.to_s)
	rss.to_s
end

def generate_html(repos, releases)
	@markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
	@repo_name = ENV['GITHUB_REPO_NAME']

	@repos = repos
	@releases = releases

	h = File.open("./views/index.erb").read
	template = ERB.new(h)

	template.result
end

def fetch_and_commit
	client = Octokit::Client.new(:access_token => ENV['GITHUB_API_TOKEN'])
	repo_name = ENV['GITHUB_REPO_NAME']
	repositories = JSON.parse(File.read('repositories.json'))

	repos = repositories.collect {|p| r = client.repository(p); Repo.new(r.node_id, r.full_name, r.name, r.html_url, r.description, r.homepage, r.forks_count, r.watchers_count, r.subscribers_count)}.sort_by {|i| i.watchers_count}.reverse

	# Take the first 100 repos ordered by release date
	releases = repos.collect do |repo|
		rs = client.releases(repo.full_name)
		releases = rs.select {|p| !(p.prerelease or p.draft)}.collect {|p| Release.new(repo, p.node_id, p.name, p.tag_name, p.body, p.html_url, p.created_at, p.published_at)}
	end.flatten.sort_by {|i| i.published_at}.reverse[0...100]

	# Generate the files needed

	html_str = generate_html(repos, releases)
	xml_str = generate_xml(repos, releases)

	repo_name = ENV['GITHUB_REPO_NAME']
	ref = ENV['GITHUB_REPO_BRANCH']

	html_file_path = "views/index.html"
	xml_file_path = "views/feed.xml"

	sha_latest_commit = client.ref(repo_name, ref).object.sha
	sha_base_tree = client.commit(repo_name, sha_latest_commit).commit.tree.sha

	html_sha = client.create_blob(repo_name, Base64.encode64(html_str), "base64")
	xml_sha = client.create_blob(repo_name, Base64.encode64(xml_str), "base64")

	sha_new_tree = client.create_tree(repo_name,
		[
			{
				:path => html_file_path,
	            :mode => "100644",
	            :type => "blob",
	            :sha => html_sha
	        },
	        {
				:path => xml_file_path,
	            :mode => "100644",
	            :type => "blob",
	            :sha => xml_sha
	        },
	    ],
	    {:base_tree => sha_base_tree}).sha

	sha_new_commit = client.create_commit(repo_name, "Generated new static files #{Time.now.to_s}", sha_new_tree, sha_latest_commit).sha
	updated_ref = client.update_ref(repo_name, ref, sha_new_commit)
end

fetch_and_commit()
