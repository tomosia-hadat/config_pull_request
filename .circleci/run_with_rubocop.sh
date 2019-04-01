require 'nokogiri'
require "cgi"
require 'pry'

logs=$( git fetch origin master && git diff -z --name-only FETCH_HEAD.. \
  | xargs -0 bundle exec rubocop-select \
  | xargs bundle exec rubocop\
  --require rubocop/formatter/checkstyle_formatter \
  --format RuboCop::Formatter::CheckstyleFormatter \
  | bundle exec checkstyle_filter-git diff FETCH_HEAD)
  echo $logs

content=`bundle exec ruby parse_rubocop_xml.rb $logs`
echo $content

xml_doc = Nokogiri::XML(ARGV.join(" "))
error_messages = ""
xml_doc.xpath("//file").each do |elm|
  begin
    elm.children.select{ |e| e.name == 'error' }.each do |error|
      error_messages << "- #{elm.attributes["name"].value}:#{error.attributes["line"].value}: #{error.attributes["message"].value}\\n"
    end
  rescue => e
    next
  end
end
puts CGI::escapeHTML(error_messages)

BODY="{\"body\": \"RUBOCOP ERRORS!!! \n $content  \n\n $CIRCLE_BUILD_URL\"}"
  curl -XPOST \
    -H "Authorization: token $GITHUB_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$BODY" \
    https://api.github.com/repos/:name_owner/:project_name/issues/${CI_PULL_REQUEST##*/}/comments