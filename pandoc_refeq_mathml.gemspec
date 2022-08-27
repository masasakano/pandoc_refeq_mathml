# -*- encoding: utf-8 -*-

require 'rake'
require 'date'

Gem::Specification.new do |s|
  s.name = 'pandoc_refeq_mathml'.sub(/.*/){|c| (c == File.basename(Dir.pwd)) ? c : raise("ERROR: s.name=(#{c}) in gemspec seems wrong!")}
  s.version = "0.2".sub(/.*/){|c| fs = Dir.glob('changelog{,.*}', File::FNM_CASEFOLD); raise('More than one ChangeLog exist!') if fs.size > 1; warn("WARNING: Version(s.version=#{c}) already exists in #{fs[0]} - ok?") if fs.size == 1 && !IO.readlines(fs[0]).grep(/^\(Version: #{Regexp.quote c}\)$/).empty? ; c }  # n.b., In macOS, changelog and ChangeLog are identical in default.
  # s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.bindir = 'bin'
  %w(pandoc_refeq_mathml).each do |f|
    path = s.bindir+'/'+f
    File.executable?(path) ? s.executables << f : raise("ERROR: Executable (#{path}) is not executable!")
  end
  s.authors = ["Masa Sakano"]
  s.date = %q{2022-08-27}.sub(/.*/){|c| (Date.parse(c) == Date.today) ? c : raise("ERROR: s.date=(#{c}) is not today!")}
  s.summary = %q{Add equation numbers to a pandoc-output MathML converted from LaTeX}
  s.description = <<-EOF
Add equation numbers in a crude way to a pandoc-output MathML converted from LaTeX, utilising its LaTeX aux file, and also adjust math-table alignments.
  EOF
  # s.email = %q{abc@example.com}
  s.extra_rdoc_files = [
     #"LICENSE.txt",
     "README.en.rdoc",
  ]
  s.license = 'MIT'
  s.files = FileList['.gitignore', '**/.gitignore', '*.gemspec', '[A-Z]*', '**/[A-Z]*', 'lib/**/*.rb', 'test/**/*.rb', 'test/data/*.lua', 'test/data/try01.html', 'test/data/try01_latex.aux', 'test/data/try01_tmpl.tex', 'bin/pandoc_refeq_mathml'].to_a.delete_if{ |f|
    ret = false
    arignore = IO.readlines('.gitignore')
    arignore.map{|i| i.chomp}.each do |suffix|
      if File.fnmatch(suffix, File.basename(f))
        ret = true
        break
      end
    end
    ret
  }.uniq
  s.files.reject! { |fn| File.symlink? fn }

  s.add_runtime_dependency 'nokogiri', '>= 1.13'
  s.add_development_dependency 'diff-lcs', '>= 1.5'

  s.homepage = "https://www.wisebabel.com"
  # s.rdoc_options = ["--charset=UTF-8"]  # "-e UTF-8" is now Default...

  # s.require_paths = ["lib"]	# Default "lib"
  s.required_ruby_version = '>= 2.0'  # respond_to_missing?
  s.test_files = Dir['test/**/*.rb']
  s.test_files.reject! { |fn| File.symlink? fn }
  # s.requirements << 'libmagick, v6.0' # Simply, info to users.
  # s.rubygems_version = %q{1.3.5}      # This is always set automatically!!

  ## cf. https://guides.rubygems.org/specification-reference/#metadata
  s.metadata["yard.run"] = "yri" # use "yard" to build full HTML docs.
  # s.metadata["changelog_uri"]     = "https://github.com/masasakano/slim_string/blob/master/ChangeLog"
  # s.metadata["source_code_uri"]   = "https://github.com/masasakano/slim_string"
  # s.metadata["documentation_uri"] = "https://www.example.info/gems/bestgemever/0.0.1"
end

