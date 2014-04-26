#!/usr/bin/ruby

require 'rubygems'

require 'yaml'
require 'set'
require 'pry'

require 'bundler'
Bundler.setup(:default)
require 'rugged'

@working_dir = File.join(File.dirname(__FILE__), 'tmp')

def clone_project(project)
  puts "Cloning #{project['repo']}"
  Rugged::Repository.clone_at(project['repo'], File.join(@working_dir, project['shortname']))
end

def update_project(project)
  puts "Updating #{project['repo']}"
  dir = File.join(@working_dir, project['shortname'])
  # rugged doesn't support pulls, and every rugged-based workaround looks monstrous
  %x{cd #{dir} && git pull}
end

committers_by_year = {}
committers_by_project = {}
all_committers = Set.new

@duplicate_emails = {}
yaml = YAML.load_file('duplicates.yml')
yaml['people'].each do |person|
  canonical = person['emails'].shift
  person['emails'].each do |email|
    @duplicate_emails[email] = canonical
  end
end

def canonical_email(email)
  e = @duplicate_emails[email]
  e || email
end

yaml = YAML.load_file('projects.yml')
yaml['projects'].each do |project|
  project['shortname'] = project['repo'].split('/').last
  if Dir.exist?(File.join(@working_dir, project['shortname']))
    update_project(project)
  else
    clone_project(project)
  end

  repo = Rugged::Repository.new(File.join(@working_dir, project['shortname']))
  walker = Rugged::Walker.new(repo)
  walker.push(repo.head.target)
  committers_by_project[project['shortname']] = Set.new
  walker.each do |c|
    year = c.time.year
    committers_by_year[year] = Set.new unless committers_by_year[year]
    committers_by_year[year].add(canonical_email(c.author[:email]))
    committers_by_project[project['shortname']].add(canonical_email(c.author[:email]))
    all_committers.add(canonical_email(c.author[:email]))
  end
end

reference = committers_by_year.dup

puts "There were #{all_committers.length} committers in total."

committers_by_year.each do |year, committers|
  total = committers.length
  reference.each do |y, c|
    next unless y < year
    committers -= c
  end
  new = committers.length
  puts "#{year} had #{total} committers, of which #{new} were new"
end

committers_by_project.each do |project, committers|
  total = committers.length
  puts "#{project} had #{committers.length} committers"
end
