require "bundler/gem_tasks"
require 'sass/util'
require 'sass/script'
require 'sprockets/standalone'
require 'unpoly/rails/version'
require 'json'

module Unpoly
  module Tasks
    SPROCKETS_MANIFESTS = %w(
      unpoly.js
      unpoly.css
      unpoly-legacy.js
      unpoly-legacy.css
      unpoly-bootstrap3.js
      unpoly-bootstrap3.css
    )
    SPROCKETS_SOURCES = %w(lib/assets/javascripts lib/assets/stylesheets)
    SPROCKETS_OUTPUT_FOLDER = 'dist'
    NPM_MANIFEST = 'package.json'
    VISIBLE_TASKS = %w(publish:build publish:commit publish:release publish:all)
  end
end

Sprockets::Standalone::RakeTask.new(:source_assets) do |task, sprockets|
  task.assets   = Unpoly::Tasks::SPROCKETS_MANIFESTS
  task.sources  = Unpoly::Tasks::SPROCKETS_SOURCES
  task.output   = Unpoly::Tasks::SPROCKETS_OUTPUT_FOLDER
  task.compress = false
  task.digest   = false
  sprockets.js_compressor  = nil
  sprockets.css_compressor = nil
end

Sprockets::Standalone::RakeTask.new(:minified_assets) do |task, sprockets|
  task.assets   = Unpoly::Tasks::SPROCKETS_MANIFESTS
  task.sources  = Unpoly::Tasks::SPROCKETS_SOURCES
  task.output   = Unpoly::Tasks::SPROCKETS_OUTPUT_FOLDER
  task.compress = false
  task.digest   = false
  sprockets.js_compressor  = :uglifier
  sprockets.css_compressor = :sass
end

namespace :publish do
  desc 'Build release artifacts'
  task :build do
    Rake::Task['minified_assets:compile'].invoke
    Unpoly::Tasks::SPROCKETS_MANIFESTS.each do |manifest|
      source = "dist/#{manifest}"
      target = "dist/#{manifest.sub(/\.([^\.]+)$/, '.min.\\1')}"
      File.rename(source, target)
    end
    Rake::Task['source_assets:compile'].invoke
    Rake::Task['npm:bump_version'].invoke
  end

  desc 'Commit and push build release artifacts'
  task :commit do
    commands = [
      "git add #{Unpoly::Tasks::SPROCKETS_OUTPUT_FOLDER}",
      "git add #{Unpoly::Tasks::NPM_MANIFEST}",
      "git commit -m 'Release artifacts for version #{Unpoly::Rails::VERSION}'",
      "git push"
    ]
    commands.each do |command|
      system(command) or raise "Error running command: #{command}"
    end
  end

  desc 'Release new version to all package managers'
  task :release do
    Rake::Task['release'].invoke
    Rake::Task['npm:publish'].invoke
  end

  desc 'Remind user to update unpoly.com'
  task :remind_to_update_site do
    puts "Now remember to update unpoly.com so user see the updated CHANGELOG and CDN link!"
  end

  desc 'Build artifacts, push to git and release to package managers'
  task :all => [:build, :commit, :release, :remind_to_update_site] do
  end

end

namespace :npm do

  task :bump_version do
    data = File.read(Unpoly::Tasks::NPM_MANIFEST)
    json = JSON.load(data)
    # Sanity-check the parsed JSON
    json['version'] or raise 'No "version" key found in package.json'
    json['version'] = Unpoly::Rails::VERSION
    data = JSON.pretty_generate(json)
    File.open(Unpoly::Tasks::NPM_MANIFEST, 'w') do |file|
      file.write data
    end
  end

  task :publish do
    system('npm publish') or raise 'Could not publish npm module'
  end

end

# Clean up task list in `rake -T`
Rake::Task.tasks.each do |task|
  unless Unpoly::Tasks::VISIBLE_TASKS.include?(task.name)
    task.clear_comments
  end
end
