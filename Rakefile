require 'json'
require 'yaml'

desc "Build up build request payload file based on information in .travis.yml"
task :build_payload do
  config = YAML.load_file('.travis.yml').to_json
  payload = {
    "request"=> {
      "message"=>"Build php-src-builder",
      "repository"=>{
        "owner_name"=>"travis-ci",
        "name"=>"php-src-builder"
        },
      "branch"=>"master",
      "config"=>config
      }
    }
  File.open('payload', 'w') do |f|
    f.puts payload.to_json
  end
end

desc "Issue build request"
task :build => [:build_payload] do
  `curl -s -X POST -H Content-Type: application/json -H #{ENV["TRAVIS_TOKEN"]} -d @payload https://api.travis-ci.com/requests`
end
