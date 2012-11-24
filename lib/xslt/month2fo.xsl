<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:maf="http://www.matthiasferber.net/xmlns"
  xmlns:fo="http://www.w3.org/1999/XSL/Format"
  
  exclude-result-prefixes="#all"
>
  <!-- Attribute set functions -->
  <!-- FIXME: why can't these be xsl:variables? -->
  
  <!-- 
    Font configuration is limited to (apparently) a subset of installed
    TTF fonts; dfont font files are not directly usable.  See notes in
    Evernote and in fop.xconf for more details.  Font handling in FOP
    is generally a nightmare.
  -->
  
  <!-- Candidate heading fonts: Helvetica; Gill Sans MT; Lucida
    Blackletter (suitcase) if I'm feeling frivolous) -->
  
  <xsl:function name="maf:month-header-font">
    <xsl:attribute name="font-family">Franklin Gothic Medium</xsl:attribute>
    <xsl:attribute name="font-size">24</xsl:attribute>
    <xsl:attribute name="font-weight">normal</xsl:attribute>
  </xsl:function>
  
  <xsl:function name="maf:date-header-font">
    <xsl:attribute name="font-family">Franklin Gothic Medium</xsl:attribute>
    <xsl:attribute name="font-size">16pt</xsl:attribute>
    <xsl:attribute name="font-weight">normal</xsl:attribute>
  </xsl:function>
  
  <xsl:function name="maf:summary-font">
    <xsl:attribute name="font-family">Franklin Gothic Book</xsl:attribute>
    <xsl:attribute name="font-size">11pt</xsl:attribute>
    <xsl:attribute name="font-weight">normal</xsl:attribute>
  </xsl:function>
  
  <xsl:function name="maf:indented-paragraph-formatting">
    <xsl:attribute name="text-indent">0.25in</xsl:attribute>
  </xsl:function>

  <xsl:function name="maf:month-header-formatting">
    <xsl:sequence select="maf:month-header-font()" />
    <xsl:attribute name="text-align">center</xsl:attribute>
    <xsl:attribute name="padding-top">0.5em</xsl:attribute>
    <xsl:attribute name="padding-bottom">0.5em</xsl:attribute>
    <xsl:attribute name="border-bottom-width">3px</xsl:attribute>
    <xsl:attribute name="border-bottom-style">solid</xsl:attribute>
    <xsl:attribute name="space-after">2em</xsl:attribute>
  </xsl:function>
  
  <xsl:function name="maf:date-summary-header-block-formatting">
  </xsl:function>
  
  <xsl:function name="maf:date-block-formatting">
    <xsl:sequence select="maf:date-header-font()" />
    <xsl:attribute name="border-bottom-width">2pt</xsl:attribute>
    <xsl:attribute name="border-bottom-style">solid</xsl:attribute>
  </xsl:function>
  
  <xsl:function name="maf:date-inline-formatting">
  </xsl:function>
  
  <xsl:function name="maf:summary-block-formatting">
    <xsl:sequence select="maf:summary-font()" />
    <xsl:attribute name="text-align">left</xsl:attribute>
    <xsl:attribute name="margin-top">0.3em</xsl:attribute>
    <xsl:attribute name="margin-bottom">0.3em</xsl:attribute>
    <xsl:attribute name="padding-bottom">0.3em</xsl:attribute>
    <xsl:attribute name="border-bottom-width">1pt</xsl:attribute>
    <xsl:attribute name="border-bottom-style">solid</xsl:attribute>
  </xsl:function>

  <xsl:function name="maf:summary-inner-block-formatting">
  </xsl:function>
  
  <xsl:function name="maf:main-block-formatting">
    <xsl:sequence select="maf:main-font()" />
    <xsl:attribute name="margin-left">2em</xsl:attribute>
    <xsl:attribute name="space-before">1em</xsl:attribute>
    <xsl:attribute name="space-after">2em</xsl:attribute>
    <xsl:attribute name="line-height">1.5</xsl:attribute>
  </xsl:function>
  
  <xsl:function name="maf:blockquote-block-formatting">
    <xsl:sequence select="maf:blockquote-font()" />
    <xsl:attribute name="margin-left">0.5in</xsl:attribute>
    <xsl:attribute name="space-before">1em</xsl:attribute>
    <xsl:attribute name="space-after">1em</xsl:attribute>
  </xsl:function>
  

  <!-- Candidate main-text fonts: Constantia (old-style numerals, tight
    spacing); Baskerville (.ttc); Bell MT (.dfont); Garamond (suitcase);
    Georgia; Goudy Old Style (suitcase); Lucida Bright (suitcase) -->
  <xsl:function name="maf:main-font" as="node()*">
    <xsl:attribute name="font-family">Constantia</xsl:attribute>
    <xsl:attribute name="font-size">11pt</xsl:attribute>
    <xsl:attribute name="font-weight">normal</xsl:attribute>
    <xsl:attribute name="line-height">130%</xsl:attribute>
  </xsl:function>
  
  <xsl:function name="maf:blockquote-font">
    <xsl:sequence select="maf:main-font()[local-name(.) ne 'font-size']" />
    <xsl:attribute name="font-size">10pt</xsl:attribute>
  </xsl:function>
  

  
  <!--
    template
  -->
  <xsl:template match="/">
    <fo:root>

      <fo:layout-master-set>
        <fo:simple-page-master
          master-name="main"
          page-height="11in"
          page-width="8.5in"
          margin-top="0.5in"
          margin-bottom="0.5in"
          margin-left="1in"
          margin-right="0.75in"
        >
          <fo:region-body />
        </fo:simple-page-master>
      </fo:layout-master-set>
    
      <fo:page-sequence master-reference="main">
        <fo:flow flow-name="xsl-region-body">
          
            <!--
              Start new months on odd-numbered pages, so when printed duplex
              the new month always starts on a new sheet of paper
            -->
            
            <!-- month header -->
            <fo:block break-before="odd-page">
              <xsl:sequence select="maf:month-header-formatting()" />
              <fo:inline>
                <xsl:value-of select="
                  maf:format-month-year(journal/@month, journal/@year)
                "/>
              </fo:inline>
            </fo:block>
            
            <!-- entries -->
            <xsl:apply-templates select="journal/entry" />
            
        </fo:flow>
      </fo:page-sequence>
    </fo:root>
  </xsl:template>
  
  <xsl:template match="entry">
    <fo:block keep-together="1"><!-- date/summary header -->
      <xsl:sequence select="maf:date-summary-header-block-formatting()" />
      <fo:block><!-- date -->
        <xsl:sequence select="maf:date-block-formatting()" />
        <fo:inline>
          <xsl:sequence select="maf:date-inline-formatting()" />
          <xsl:value-of select="format-date(xs:date(@date), '[F], [MNn] [D], [Y]')" />
        </fo:inline>
      </fo:block>
      <!-- Don't render the summary at all unless it has content -->
      <xsl:if test="exists(summary/(text()|*))">
        <fo:block><!-- summary -->
          <xsl:sequence select="maf:summary-block-formatting()" />
          <fo:block>
            <xsl:sequence select="maf:summary-inner-block-formatting()" />
            <xsl:apply-templates mode="#current" select="summary/p/(text()|*)" />
          </fo:block>
        </fo:block>
      </xsl:if>

    </fo:block>
    <fo:block keep-with-previous="1">
      <xsl:sequence select="maf:main-block-formatting()" />
      <xsl:apply-templates select="text/*" />
    </fo:block>
  </xsl:template>
  
  <!-- summary content -->
  <xsl:template match="summary/p">
    <fo:block>
      <xsl:apply-templates />
    </fo:block>
  </xsl:template>
  
  <!-- text paragraph -->
  <xsl:template match="text//p">
    <fo:block>
    
      <!-- I use a convention where subsections in the text are marked
        with [Label] of some kind at the start of the paragraph. Make
        those run flush left and set them off from the preceding para.
        All normal text paragraphs are indented. -->
      <!-- Start by getting the first child of the <p>, IF it's text() -->
      <xsl:variable name="first-child-text"
        select="(*|text())[1][self::text()]"
      />
      <xsl:choose>
      
        <xsl:when test="starts-with($first-child-text, '[')">
        
          <!-- set off from preceding para unless this is 1st para -->
          <xsl:if test="position() ne 1">
            <xsl:attribute name="space-before">1em</xsl:attribute>
          </xsl:if>
          
          <!-- extract the label text and format it for emphasis -->
          <xsl:analyze-string select="$first-child-text"
            regex="^\[(.*)\]\s+(.*)$"
          >
            <xsl:matching-substring>
              <fo:inline font-weight="bold" font-style="italic"
                background-color="#eee"
              >
                <xsl:value-of select="regex-group(1)" />
              </fo:inline>
              <xsl:text> — </xsl:text>
              <xsl:value-of select="regex-group(2)" />
            </xsl:matching-substring>
            <xsl:non-matching-substring>
              <xsl:value-of select="$first-child-text" />
            </xsl:non-matching-substring>
          </xsl:analyze-string>
          
        </xsl:when>
        <xsl:otherwise>
        
          <!-- don't indent first paragraph (if it's a normal para) -->
          <xsl:if test="not(position() eq 1)">
            <xsl:sequence select="maf:indented-paragraph-formatting()" />
          </xsl:if>
          <xsl:apply-templates select="text()|*" />
          
        </xsl:otherwise>
      </xsl:choose>

    </fo:block>
  </xsl:template>
  
  <!-- blockquote section (contains p) -->
  <xsl:template match="blockquote">
    <fo:block>
      <xsl:sequence select="maf:blockquote-block-formatting()" />
      <xsl:apply-templates select="*" />
    </fo:block>
  </xsl:template>
  
  <!-- italics -->
  <xsl:template match="i|em">
    <fo:inline font-style="italic">
      <xsl:apply-templates select="text()|*" />
    </fo:inline>
  </xsl:template>
  
  <!-- bold -->
  <xsl:template match="b|strong">
    <fo:inline font-weight="bold">
      <xsl:apply-templates select="text()|*" />
    </fo:inline>
  </xsl:template>
  
  <!-- unordered list -->
  <xsl:template match="ul">
    <fo:list-block provisional-distance-between-starts="1em"
      provisional-label-separation="0.5em" margin-left="3em"
      space-before="1em" space-after="1em"
    >
      <xsl:apply-templates select="li" />
    </fo:list-block>
  </xsl:template>
  
  <xsl:template match="li">
    <fo:list-item>
      <fo:list-item-label end-indent="label-end()">
        <fo:block>•</fo:block>
      </fo:list-item-label>
      <fo:list-item-body start-indent="body-start()">
        <fo:block>
          <xsl:apply-templates select="text()|*" />
        </fo:block>
      </fo:list-item-body>
    </fo:list-item>
  </xsl:template>
  
  <!-- catchall for unhandled elements: copy text and children -->
  <xsl:template match="element()">
    <xsl:copy>
      <xsl:apply-templates mode="#current" select="text()|*" />
    </xsl:copy>
  </xsl:template>
  
  
  <!-- format month header -->
  <xsl:function name="maf:format-month-year" as="xs:string">
    <xsl:param name="month" as="xs:string" />
    <xsl:param name="year" as="xs:string" />
    
    <xsl:variable name="first" as="xs:date" select="xs:date(concat($year, '-', $month, '-01'))" />
    <xsl:value-of select="format-date($first, '[MNn] [Y]')" />
  </xsl:function>
</xsl:stylesheet>
