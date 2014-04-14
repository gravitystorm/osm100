#!/usr/bin/ruby

require 'yaml'
require 'rugged'
require 'set'
require 'pry'

@working_dir = File.join(File.dirname(__FILE__), 'tmp')

def clone_project(project)
  puts "Cloning #{project['repo']}"
  Rugged::Repository.clone_at(project['repo'], File.join(@working_dir, project['shortname']))
end

committers = {}

yaml = YAML.load_file('projects.yml')
yaml['projects'].each do |project|
  project['shortname'] = project['repo'].split('/').last
  unless Dir.exists?(File.join(@working_dir, project['shortname']))
    clone_project(project)
  end

  repo = Rugged::Repository.new(File.join(@working_dir, project['shortname']))
  walker = Rugged::Walker.new(repo)
  walker.push(repo.head.target)
  walker.each do |c|
    year = c.time.year
    committers[year] = Set.new unless committers[year]
    committers[year].add(c.author[:email])
  end
end

reference = committers.dup

committers.each do |year, committers|
  total = committers.length
  reference.each do |y, c|
    next unless y < year
    committers = committers - c
  end
  new = committers.length
  puts "#{year} had #{total} committers, of which #{new} were new"
end
