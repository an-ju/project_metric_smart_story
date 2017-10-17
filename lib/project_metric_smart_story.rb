require "project_metric_smart_story/version"
require "faraday"
require "json"

class ProjectMetricSmartStory
  attr_reader :raw_data

  def initialize(credentials, raw_data = nil)
    @project = credentials[:tracker_project]
    @conn = Faraday.new(url: 'https://www.pivotaltracker.com/services/v5')
    @conn.headers['Content-Type'] = 'application/json'
    @conn.headers['X-TrackerToken'] = credentials[:tracker_token]
    @raw_data = raw_data
  end

  def refresh
    @score = @image = nil
    @raw_data ||= stories
  end

  def raw_data=(new)
    @raw_data = new
    @score = nil
    @image = nil
  end

  def score
    @raw_data ||= stories
    @score ||= @raw_data.empty? ? 0.0 : smart_stories.length / @raw_data.length.to_f
  end

  def image
    @raw_data ||= stories
    @image ||= { chartType: 'smart_story',
                 titleText: 'Story Descriptions',
                 data: {
                   smart_stories: digest_of(smart_stories),
                   non_smart_stories: digest_of(non_smart_stories)
                 } }.to_json
  end

  def self.credentials
    %I[tracker_project tracker_token]
  end

  private

  def stories
    JSON.parse(@conn.get("projects/#{@project}/stories").body).select { |s| s['kind'].eql? 'story' }
  end

  def smart_stories
    @raw_data.reject { |s| check_smart(s['description']).nil? }
  end

  def non_smart_stories
    @raw_data.select { |s| check_smart(s['description']).nil? }
  end

  def check_smart(s)
    s.nil? ? nil : /as.*so[ ]?that.*/.match(s.downcase)
  end

  def digest_of(stories)
    stories.map { |s| { title: s['title'], description: s['description'], id: s['id'] } }
  end
end
