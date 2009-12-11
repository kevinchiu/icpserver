require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'

desc "Generate the documentation"
Rake::RDocTask::new do |rdoc|
  rdoc.rdoc_dir = 'ym4r-tools-doc/'
  rdoc.title    = "YM4R Tools Documentation"
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
end

desc "Package the library as a ZIP"
Rake::PackageTask.new("ym4r-tools","0.5.2") do |pkg|
  pkg.need_zip = true
  pkg.package_files.include("tools/*.rb","README","MIT-LICENSE","rakefile.rb")
end
