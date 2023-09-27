# "instances-api" (which is a Instances API website for Invidious.)
# Copyright (C) 2023  Invidious Team
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require "http/client"
require "kemal"
require "uri"

require "./instances/refresh"

Kemal::CLI.new ARGV

macro rendered(filename)
  render "src/instances/views/#{{{filename}}}.ecr"
end

alias Instance = NamedTuple(
  flag: String?,
  region: String?,
  stats: JSON::Any?,
  cors: Bool?,
  api: Bool?,
  type: String,
  uri: String,
  monitor: JSON::Any?)

INSTANCES = {} of String => Instance

InstanceRefreshJob.new.begin

before_all do |env|
  env.response.headers["X-XSS-Protection"] = "1; mode=block"
  env.response.headers["X-Content-Type-Options"] = "nosniff"
  env.response.headers["Referrer-Policy"] = "same-origin"
  env.response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains; preload"
end

get "/" do |env|
  sort_by = env.params.query["sort_by"]?
  sort_by ||= "type,users"

  instances = sort_instances(INSTANCES, sort_by)

  rendered "index"
end

get "/instances.json" do |env|
  env.response.headers["Access-Control-Allow-Origin"] = "*"
  env.response.content_type = "application/json; charset=utf-8"

  sort_by = env.params.query["sort_by"]?
  sort_by ||= "type,users"

  instances = sort_instances(INSTANCES, sort_by)

  if env.params.query["pretty"]?.try &.== "1"
    instances.to_pretty_json
  else
    instances.to_json
  end
end

error 404 do |env|
  env.redirect "/"
  halt env, status_code: 302, response: ""
end

static_headers do |response, filepath, filestat|
  response.headers.add("Cache-Control", "max-age=86400")
end

SORT_PROCS = {
  "health"   => ->(name : String, instance : Instance) { -(instance[:monitor]?.try &.["30dRatio"]["ratio"].as_s.to_f || 0.0) },
  "location" => ->(name : String, instance : Instance) { instance[:region]? || "ZZ" },
  "name"     => ->(name : String, instance : Instance) { name },
  "signup"   => ->(name : String, instance : Instance) { instance[:stats]?.try &.["openRegistrations"]?.try { |bool| bool.as_bool ? 0 : 1 } || 2 },
  "type"     => ->(name : String, instance : Instance) { instance[:type] },
  "cors"     => ->(name : String, instance : Instance) { instance[:cors] == nil ? 2 : instance[:cors] ? 0 : 1 },
  "api"      => ->(name : String, instance : Instance) { instance[:api] == nil ? 2 : instance[:api] ? 0 : 1 },
  "users"    => ->(name : String, instance : Instance) { -(instance[:stats]?.try &.["usage"]?.try &.["users"]["total"].as_i || 0) },
  "version"  => ->(name : String, instance : Instance) { instance[:stats]?.try &.["software"]?.try &.["version"].as_s.try &.split("-", 2)[0].split(".").map { |a| -a.to_i } || [0, 0, 0] },
}

def sort_instances(instances, sort_by)
  instances = instances.to_a
  sorts = sort_by.downcase.split("-", 2)[0].split(",").map { |s| SORT_PROCS[s] }

  instances.sort! do |a, b|
    compare = 0
    sorts.each do |sort|
      first = sort.call(a[0], a[1])
      case first
      when Int32
        compare = first <=> sort.call(b[0], b[1]).as(Int32)
      when Array(Int32)
        compare = first <=> sort.call(b[0], b[1]).as(Array(Int32))
      when Float64
        compare = first <=> sort.call(b[0], b[1]).as(Float64)
      when String
        compare = first <=> sort.call(b[0], b[1]).as(String)
      else
        raise "Invalid proc"
      end
      break if compare != 0
    end
    compare
  end
  instances.reverse! if sort_by.ends_with?("-reverse")
  instances
end

gzip true
public_folder "assets"

Kemal.config.powered_by_header = false
Kemal.run
