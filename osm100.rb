#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require 'rugged'
require 'set'
require 'pry'
require 'optparse'

options = { update: false, committers: false }
optparse = OptionParser.new do |opts|
  opts.banner = 'Usage: osm100.rb [options]'

  opts.on('--[no-]update', 'Update cloned projects, default: false')
  opts.on('--[no-]committers', 'Output list of committers, default: false')

  opts.on_tail('-h', '--help', 'Show this message') do
    puts opts
    exit
  end
end
optparse.parse!(into: options)

@working_dir = File.join(File.dirname(__FILE__), 'tmp')

def clone_project(project)
  puts "Cloning #{project['repo']}"
  Rugged::Repository.clone_at(project['repo'], File.join(@working_dir, project['shortname']))
end

def update_project(project)
  puts "Updating #{project['repo']}"
  dir = File.join(@working_dir, project['shortname'])
  # rugged doesn't support pulls, and every rugged-based workaround looks monstrous
  `cd #{dir} && git pull`
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
    if options[:update]
      update_project(project)
    else
      puts 'skipping update'
    end
  else
    clone_project(project)
  end

  repo = Rugged::Repository.new(File.join(@working_dir, project['shortname']))
  walker = Rugged::Walker.new(repo)
  walker.push(repo.head.target_id)
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

committers_by_year.dup.each do |year, committers|
  total = committers.length
  reference.each do |y, c|
    next unless y < year

    committers -= c
  end
  new = committers.length
  puts "#{year} had #{total} committers, of which #{new} were new"
end

committers_by_project.each do |project, committers|
  puts "#{project} had #{committers.length} committers"
end

appearances = []
all_committers.each do |committer|
  puts committer if options[:committers]
  years = []
  committers_by_year.each do |year, committers|
    years << year if committers.include?(committer)
  end
  appearances << years
end

cohorts = {}
committers_by_year.each_key do |year|
  cohorts[year] = {}
  appearances.each do |years|
    next unless years.include?(year)

    first_year = years.min
    if cohorts[year][first_year]
      cohorts[year][first_year] += 1
    else
      cohorts[year][first_year] = 1
    end
  end
end

puts cohorts
