require 'sinatra'
require 'json'
require 'redis'
require 'octokit'

get '/' do
  'ok'
end

post '/webhook' do
  logger.info "[params] #{params.inspect}"
  subject = params['subject'].to_s
  body    = params['body'].to_s

  # Do nothing unless reply
  return unless subject.to_s.match(/^Re:/)

  # Extract feedback_id from subject
  feedback_id = subject.scan(/\(FB-(\d+)\)/).flatten.first.to_i

  # Extract feedback content from Email body
  feedback_content = body.split(/^\d{4}.\d{1,2}.\d{1,2}.+:$/).first.strip

  # Get issue number
  redis = Redis.new(url: ENV['REDIS_URL'])
  redis_key = "feedbacks:#{feedback_id}:issue_number"
  issue_number = redis.get(redis_key)
  unless issue_number
    octokit = Octokit::Client.new(access_token: ENV['GITHUB_TOKEN'])
    issue = octokit.search_issues("[FB-#{feedback_id}] in:title repo:fukayatsu/esa author:aridori", sort: 'created', order: 'asc').items.first
    issue_number = issue.number
    redis.set(redis_key, issue_number)
  end

  # Add comment on the issue
  octokit.add_comment('fukayatsu/esa', issue_number, "feedback-sync:\n\n#{feedback_content}")

  logger.info '[github comment] done'
end