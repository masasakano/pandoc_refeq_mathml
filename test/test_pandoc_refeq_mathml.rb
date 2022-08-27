# -*- encoding: utf-8 -*-
#
# Usage(at-Parent-directory): RUBYLIB=$RUBYLIB:./lib ruby test/test_pandoc_refeq_mathml.rb

require 'open3'
require 'tempfile'
require 'diff/lcs'
require 'diff/lcs/string'

$stdout.sync=true
$stderr.sync=true
# print '$LOAD_PATH=';p $LOAD_PATH
arlibrelpath = []
arlibbase = %w(pandoc_refeq_mathml)	# Write those that are loaded inside a library to make their absolute paths be displayed.

arlibbase.each do |elibbase|
  arAllPaths = []
  er=nil
  pathnow = nil
  (['../lib/', 'lib/', ''].map{|i| i+elibbase+'/'} + ['']).each do |dir|
    begin
      s = dir+File.basename(elibbase)
      arAllPaths.push(s)
      require s
      pathnow = s
      break
    rescue LoadError => er
    end
  end	# (['../lib/', 'lib/', ''].map{|i| i+elibbase+'/'} + '').each do |dir|

  if pathnow.nil?
    warn "Warning: All the attempts to load the following files have failed.  Abort..."
    warn arAllPaths.inspect
    warn " NOTE: It may be because a require statement in that file failed, 
rather than requiring the file itself.
 Check with  % ruby -r#{File.basename(elibbase)} -e p
 or maybe add  env RUBYLIB=$RUBYLIB:`pwd`"
    # p $LOADED_FEATURES.grep(/#{Regexp.quote(File.basename(elibbase)+'.rb')}$/)
    raise er
  else
#print pathnow," is loaded!\n"
    arlibrelpath.push pathnow
  end
end	# arlibbase.each do |elibbase|

print "NOTE: Library relative paths: "; p arlibrelpath
print "NOTE: Library full paths:\n"
arlibbase.each do |elibbase|
  p $LOADED_FEATURES.grep(/#{Regexp.quote(File.basename(elibbase)+'.rb')}$/)
end



#################################################
# Unit Test
#################################################

gem "minitest"
# require 'minitest/unit'
require 'minitest/autorun'
# MiniTest::Unit.autorun

class TestUnitPandocRefeqMathml < MiniTest::Test
  T = true
  F = false

  def setup
    @exefile  = __dir__ + "/../bin/pandoc_refeq_mathml"
    @auxfile  = __dir__ + "/data/try01_latex.aux"
    @htmlfile = __dir__ + "/data/try01.html"

    # For integration tests, the lib directory should be at the top in RUBYLIB.
    # Use it like:  "RUBYLIB=#{@rubylib4exe} #{@exefile}"
    @rubylib4exe = sprintf "%s/../lib:%s", __dir__, ENV['RUBYLIB']

    # Array of IOs for temporary files (automatically set in generate_tmpfile())
    @tmpfiles = []
  end

  def teardown
    @tmpfiles.each do |ef|
      ef.close if !ef.closed? 
      File.unlink(ef.path)
    end
  end

  # @option root [#to_s] Root-name of the temporary filename
  def generate_tmpfile(root=File.basename($0))
    io_tmpfile = Tempfile.open(root.to_s)
    $stderr.print "TEST: Tmpfile="+io_tmpfile.path if ENV.key?('PRINT_TMPFILE') # To display Filename (NOTE the file will be removed when the script ends anyway.)
    @tmpfiles.push io_tmpfile
    [io_tmpfile, io_tmpfile.path]
  end

  def test_pandoc_refeq_mathml
    auxstr = File.read @auxfile
    htmlstr = File.read @htmlfile
    page00 = Nokogiri::HTML(htmlstr)
    page   = Nokogiri::HTML(htmlstr)
    io_tmp, _ = generate_tmpfile(__method__)

    prm = PandocRefeqMathml.new page, auxstr, logio: io_tmp, is_verbose: true
    prm.alter_html!

    # an Equation (LaTeX: \begin{equation})
    math1_org = page00.css("math:first-of-type")[0]
    math1_rev = prm.page.css("math:first-of-type")[0]
    lcs = math1_org.to_s.diff(math1_rev.to_s)
    assert_equal 1, lcs.size, 'Diff-size should be 1 (one continuous addition only)'
    assert_operator 90, '<', lcs[0].size, 'Number of different characters should be larger than 90'
    assert_operator 99, '>', lcs[0].size, 'Number of different characters should be smaller than 99: Diff='+join_diff_chg(lcs).inspect  # "mrow><mtext id=\"square_pm\" style=\"padding-left:1em; text-align:right;\">(36)</mtext></mrow><"
    assert((%r@</mtext>@ !~ math1_org.to_s), '</mtext> should not be included')
    assert_match(%r@</mtext></mrow></mrow>@, math1_rev.to_s, '</mtext></mrow></mrow> should be included')
    assert_match(%r@#{Regexp.quote "(55)</mtext></mtd>"}@, prm.page.to_s, 'Equation number (55) should be correctly placed despite LaTeX comment lines')  # in data/try01_latex.aux: {eq_approx_symmetric_frac_1order}{{55}{39}{割り算}{equation.4.52}{}}
    assert_equal "55", prm.page.css('a[href="#eq_approx_symmetric_frac_1order"]')[0].text, "Eq.55 should be correctly referencing"

    mtds = prm.page.css("math mtable mtr")[2].css("mtd")
    assert_equal "right",  mtds[0]["columnalign"]
    assert_equal "center", mtds[1]["columnalign"], "align should be center: "+mtds[1]
    assert_equal "left",   mtds[2]["columnalign"]
    # NOTE: --no-fixalign is tested in test_integration()

    io_tmp.rewind
    msg_log = io_tmp.read
    assert_match(%r@label=.?sec_@, msg_log, "Warning message should be present in the log file because Equation-ID is not found for a label for a Section: \n> "+msg_log)
  end

  # Integration tests
  #
  # RUBYLIB=./lib:$RUBYLIB bin/pandoc_refeq_mathml --aux test/data/try01_latex.aux test/data/try01.html > STDOUT/STDERR
  def test_integration
    com = sprintf "RUBYLIB=%s %s --aux=%s --no-fixalign", @rubylib4exe, @exefile, @auxfile  # Logfile => STDERR, fixalign=no

    ## From STDIN, out to STDOUT, log-file to STDERR
    out, err, stat = Open3.capture3(com, stdin_data: File.read(@htmlfile))
    assert_equal 0, stat, "Execution fails (stat=#{stat}): com=(#{@exefile}). STDERR="+err
    assert_match(%r@label=.?sec_@, err, "Warning message should be present in STDERR because Equation-ID is not found for a label for a Section: \n> "+err)
    assert_operator 5, '<=', out.scan(%r@(?=</mtext>)@).count, 'There should be many </mtext>. out[0..100]='+out#[0..100]
    assert_match(%r@\bcolumnalign="right"@,  out, 'Sanity check columnalign')
    refute_match(%r@\bcolumnalign="center"@, out, 'With --no-fixalign center columnalign should not exist, but..')
  end

  # Read a 2-dim Array of Diff::LCS::Change and convert it to a single Array of them
  #
  # Each array-element Diff may (or usually) have more than 1 character.
  # And therefore, it should be far more readable for humans.
  # Here is an example.
  #
  #   # [[<Diff::LCS::Change: ["+", 1, "x"]>, <Diff::LCS::Change: ["+", 2, "y"]>], [<Diff::LCS::Change: ["-", 2, "y"]>]]
  #   # => [<Diff::LCS::Change: ["+", 1, "xy"]>, <Diff::LCS::Change: ["-", 2, "y"]>]
  #
  # You can still patch it.
  #
  #   s2 == s1.patch( [join_diff_chg(Diff::LCS.diff(s1, s2))] )
  #
  # However, +s2.unpatch [join_diff_chg(...)]+ raises RuntimeError.
  # I think it works by starting from the beginning, swapping "`+`" and "`-`",
  # where interpreting "`-`"+0 as inserting before pos=0 and "`+`"+1 as deleting after pos=1.
  #
  # @param arlcs [Array<Array<<Diff::LCS::Change>>]
  # @return [Array<Diff::LCS::Change>]
  def join_diff_chg(ar2lcs)
    arlcs = []  # ar2lcs.flatten actually also flattens the contents of Diff::LCS::Change !
                # Therefore, this is a custom Array#flatten
    ar2lcs.each do |ea1|
      ea1.each do |ea2|
        arlcs.push ea2
      end
    end

    return arlcs if arlcs.empty?

    pos = pos_ini = arlcs[0].position - 99
    strdiff       = nil
    action_now    = nil

    arret = []
    arlcs.each do |ed|  # ed: EachDiff
      if (pos != ed.position - 1) || (ed.action != action_now)
        # The previous series has ended.
        arret.push Diff::LCS::Change.new(action_now, pos_ini, strdiff) if action_now # unless the very first one
        pos = pos_ini = ed.position
        strdiff       = ed.element.dup
        action_now    = ed.action
        next
      end

      pos = ed.position
      strdiff << ed.element
    end
    arret.push Diff::LCS::Change.new(action_now, pos_ini, strdiff)
    arret
  end
end	# class TestUnitPandocRefeqMathml < MiniTest::Test

