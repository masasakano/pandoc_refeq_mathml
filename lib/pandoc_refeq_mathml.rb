# coding: utf-8

require 'nokogiri'

# Class to handle MathML and LaTeX aux
#
class PandocRefeqMathml

  attr_reader :page, :aux

  # Alignment for LaTeX eqnarray.
  EQNARRAY_ALIGNS = %w(right center left)

  # @param page [Nokogiri::HTML4::Document]
  # @param auxstr [String] String of the contents of a LaTeX aux file
  # @param logio [IO] Output IO for logs. You may give +IO.open("/dev/null", "w")+. Def: $stderr
  # @param is_verbose [Boolean] If true (Default), verbose.
  def initialize(page, auxstr, logio: $stderr, is_verbose: true)
    @page = page
    @auxstr = auxstr
    @logio = logio
    @is_verbose = is_verbose
    @hslabel = {}  # String(label) => String(EqNumber), which have been detected.
  end

  # @param taga [Nokogiri::HTML4::Document] Nokogiri <A> object.
  # @return [String, NilClass] Label string used in +<a href=..>+. Nil if something is wrong.
  def get_label(taga)
    kwdlink = taga['href'].split('#')[1]
    return kwdlink if kwdlink == taga['data-reference']

    @logio.puts "WARNING: Inconsistent href and data-reference: "+a.to_s if @is_verbose
    return nil
  end

  # Return the equation number.
  #
  # The number is assumed to contain only numbers and maybe full-stops +[\d.]+.
  #
  # @return [String, NilClass] Equation number guessed from the Aux file. nil if something goes wrong.
  def get_eq_num(kwdlink)
    mat = /^\\newlabel\{#{kwdlink}\}\{\{([\d\.]+)\}\{(\d+)\}\{(.*)\}\{equation.([a-zA-Z\d\.]+)\}/.match @auxstr  # it may be like equation.B.193 (for Appendix B).
       # => #<MatchData "\\newlabel{eq_my_lab}{{65}{35}{割り算}{equation.4.62}" 1:"65" 2:"35" 3:"割り算" 4:"4.62">
    return mat[1] if mat && mat[1] && !mat[1].empty?

    ## Something is wrong. 
    str = sprintf 'WARNING: Not found equation number for label="%s" (maybe it is for a section etc?): MatchData=%s', kwdlink, mat.inspect
    @logio.puts str
    return nil
  end

  # Find the equation number inside an eqnarray (mtable)
  #
  # If it is the first equation inside the eqnarray, returns 0.
  #
  # Comments in the annotation (=LaTeX source) are removed.
  # Note although the algorithm takes into account the standard backslash
  # escape before per-cent signs, it does not consider "\verb@ab % cd@"
  # or that kind (if it is ever allowed in a LaTeX math environment!).
  #
  # @param math0 [NokogiriXmlNode] Nokogiri XML +<math>+ object that contains the equation of kwdlink
  # @param kwdlink [String] label
  # @return [Integer] Array position number (starting from 0) of the equation.
  def find_i_eq_annot(math0, kwdlink)
    annot_node= math0.css('annotation[encoding="application/x-tex"]')[0]
    annot_str = annot_node.children[0].text.gsub(%r@(?<!\\)%[^\n]*@, "")  # Comments in the annotation (=LaTeX source) are removed.
    i_eq_annot = annot_str.split(/\\\\\s*(?:\%[^\n]*)?\n?/).find_index{|ev| /\\label\{#{kwdlink}\}/ =~ ev}  # Index of the equation (starting from 0) in the eqnarray
    raise "FATAL: contact the code developer: eqnarray: "+annot_node.inspect if !i_eq_annot
    i_eq_annot
  end

  # Insert a text of Equation Number.
  #
  # Returns Integer to express the n-th number as for the location
  # of the equation with given +kwdlink+ in the eqnarray.  If it is
  # the first equation, then returns 1.
  #
  # @param kwdlink [String] label
  # @param n_eq [String] Equation number like "58", maybe "52.3"
  # @return [Integer, NilClass] nil only if something goes wrong.
  def find_insert_n_eq(kwdlink, n_eq)
    # Select the <math> tag component that hs the kwdlink
    maths = @page.css('math').select{|ep|
      /\\label\{\s*#{Regexp.quote(kwdlink)}\s*\}/ =~ (ep.css('annotation[encoding="application/x-tex"]').children[0].text.strip rescue "X")
    }
    if maths.size != 1
      if maths.size == 0
        @logio.puts 'WARNING: no math tag contains label="#{kwdlink}"'
      else
        @logio.print 'WARNING: Multiple math tags contain label="#{kwdlink}"'
        @logio.puts (@is_verbose ? ": maths="+maths.inspect : "")
      end
      return nil
    end

    mtext = sprintf '<mtext id="%s" style="padding-left:1em; text-align:right;">(%s)</mtext>', kwdlink, n_eq
    
    if maths[0].css('mtable').empty?
      # \begin{equation}
      #
      # Insert the new node (<mrow><mtext...>(65)</mtext></mrow>) as the last child of
      # the last top-level existing <mrow>; if it was added AFTER the <mrow>,
      # the <mtext> number would not be displayed on the browser!
      newnode = '<mrow>' + mtext + '</mrow>'
      begin
        maths[0].css("mrow")[0].parent.css("> mrow")[-1].add_child(newnode)
          # Between the last top-level <mrow> and <annotation>
          # n.b., simple css('mrow')[-1] would give an mrow inside another mrow!
      rescue
        msg = "FATAL: contact the code developer: equation: maths[0]="+maths[0].inspect
        @logio.puts msg
        raise msg
      end
      return 0
    else
      # \begin{eqnarray}
      newnode = '<mtd columnalign="right">' + mtext + '</mtd>'
      i_eq_annot = find_i_eq_annot(maths[0], kwdlink)

      # Insert the new node ("<mtd><mtext...>(65)</mtext></mtd>")
      mtrnode = maths[0].css('mtable mtr')[i_eq_annot]
      raise "FATAL: contact the code developer: eqnarray (mtrnode is nil): i_eq_annot=#{i_eq_annot.inspect}, kwdlink=(#{kwdlink})" if !mtrnode

      # mtrnode.css('mtd')[-1].add_next_sibling(newnode)  # does not consider multi-layer math-tables
      find_last_shallowest(mtrnode, 'mtd').add_next_sibling(newnode)
    end
    return i_eq_annot+1
  end

  # @param kwdlink [String] label
  # @param taga [NokogiriXmlNode] Nokogiri <A> object. (maybe Nokogiri::HTML4::Document etc)
  # @param n_eq_str [String] equation number string
  # @return [void]
  def alter_link_text(kwdlink, taga, n_eq_str)
    textnode = taga.children[0]
    if !textnode.text?
      @logio.puts "WARNING: Inconsistent text inside href: "+taga.to_s
      return nil
    end

    if /\A\[?#{Regexp.quote(kwdlink)}\]?\z/ !~ textnode.to_s.strip
      @logio.puts "WARNING: Strange linked-text=(#{textnode.to_s}) inside <a>: "+a.to_s if @is_verbose
    end

    taga.content=n_eq_str
  end

  # Alter the alignments of mtable originating from eqnarray
  #
  # Original is all right-aligned.
  # After alteration, it will be right, center, left (which is the specification of eqnarray).
  def alter_align_eqnarray!
    @page.css("math mtable mtr").each do |ea_mtr|
      ea_mtr.css("mtd").each_with_index do |ea_mtd, i|
        break if i >= EQNARRAY_ALIGNS.size
        ea_mtd["columnalign"]=EQNARRAY_ALIGNS[i]
      end
    end
  end

  # Alter the existing HTML Nokogiri content
  def alter_reflinks!
    all_ref_href = @page.css("a[data-reference-type=ref]")
    all_ref_href.each do |ea_nodes|
      # Gets a label from MathML
      (kwdlink = get_label(ea_nodes)) || next

      if !@hslabel.keys.include? kwdlink
        # Gets the number of the equation from Aux
        n_eq = get_eq_num(kwdlink)
        next if !n_eq
        @hslabel[kwdlink] = n_eq

        # Finds the equation in MathML and adds the number of the equation.
        find_insert_n_eq(kwdlink, n_eq) # this returns nil if something goes wrong
      elsif !@hslabel[kwdlink]
        # the label "kwdlink" has been detected, but no Equation-number was found.
        next
      end

      # Alter the original link text in MathML to Equation number.
      alter_link_text(kwdlink, ea_nodes, @hslabel[kwdlink])
    end
  end

  # @param fixalign [Boolean] fix alignments if true
  def alter_html!(fixalign: true)
    alter_align_eqnarray! if fixalign
    alter_reflinks!
  end

  # Returns the last shallowest node with the given tag-name
  #
  # @see https://stackoverflow.com/a/73459162/3577922
  #
  # @param root [NokogiriXmlNode] root node
  # @param tagname [String] Tag-name like "mrow" for which the last-shallowest is looked
  def find_last_shallowest(root, tagname)
    raise TypeError, "#{__method__}(): non-XML-node is given: (#{root.inspect})" if !root.respond_to?(:children)
    queue = [root]
    while queue.any?
      element = queue.shift
      return element if node_matching?(element, tagname)
      queue.concat element.children.reverse
    end
  end
  private :find_last_shallowest

  # @param element [NokogiriXmlNode] including Nokogiri::XML::Element
  def node_matching?(element, tagname)
    # Put your matching logic here
    element.name == tagname
  end
  private :node_matching?
end # PandocRefeqMathml

