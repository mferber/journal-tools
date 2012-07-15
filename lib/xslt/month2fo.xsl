<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:maf="http://www.matthiasferber.net/xmlns"
  xmlns:fo="http://www.w3.org/1999/XSL/Format"
  
  exclude-result-prefixes="#all"
>
  <!-- Attribute set functions -->
  
  <!-- 
    Font configuration is limited to (apparently) a subset of installed
    TTF fonts; dfont font files are not directly usable.  See notes in
    Evernote and in fop.xconf for more details.  Font handling in FOP
    is generally a nightmare.
  -->
  
  <!-- Candidate heading fonts: Helvetica; Gill Sans MT; Lucida
    Blackletter (suitcase) if I'm feeling frivolous) -->
  
  <xsl:function name="maf:month-header-font">
    <xsl:attribute name="font-family">Helvetica</xsl:attribute>
    <xsl:attribute name="font-size">24</xsl:attribute>
    <xsl:attribute name="font-weight">bold</xsl:attribute>
  </xsl:function>
  
  <xsl:function name="maf:date-header-font">
    <xsl:attribute name="font-family">Helvetica</xsl:attribute>
    <xsl:attribute name="font-size">14pt</xsl:attribute>
    <xsl:attribute name="font-weight">bold</xsl:attribute>
  </xsl:function>
  
  <xsl:function name="maf:summary-font">
    <xsl:attribute name="font-family">Helvetica</xsl:attribute>
    <xsl:attribute name="font-size">10pt</xsl:attribute>
    <xsl:attribute name="font-weight">bold</xsl:attribute>
    <xsl:attribute name="line-height">125%</xsl:attribute>
  </xsl:function>

  <!-- Candidate main-text fonts: Constantia (old-style numerals, tight
    spacing); Baskerville (.dfont); Bell MT (.dfont); Garamond (suitcase);
    Georgia; Goudy Old Style (suitcase); Lucida Bright (suitcase) -->
  <xsl:function name="maf:main-font">
    <xsl:attribute name="font-family">Constantia</xsl:attribute>
    <xsl:attribute name="font-size">11pt</xsl:attribute>
    <xsl:attribute name="font-weight">normal</xsl:attribute>
    <xsl:attribute name="line-height">130%</xsl:attribute>
  </xsl:function>
  
  
  
  <xsl:function name="maf:month-header-formatting">
    <xsl:sequence select="maf:month-header-font()" />
    <xsl:attribute name="text-align">center</xsl:attribute>
    <xsl:attribute name="padding-top">0.5em</xsl:attribute>
    <xsl:attribute name="padding-bottom">0.5em</xsl:attribute>
    <!--<xsl:attribute name="border-top-width">3px</xsl:attribute>
    <xsl:attribute name="border-top-style">solid</xsl:attribute>-->
    <xsl:attribute name="border-bottom-width">3px</xsl:attribute>
    <xsl:attribute name="border-bottom-style">solid</xsl:attribute>
    <!--<xsl:attribute name="border-left-width">3px</xsl:attribute>
    <xsl:attribute name="border-left-style">solid</xsl:attribute>
    <xsl:attribute name="border-right-width">3px</xsl:attribute>
    <xsl:attribute name="border-right-style">solid</xsl:attribute>-->
    <xsl:attribute name="space-after">2em</xsl:attribute>
  </xsl:function>
  
  <xsl:function name="maf:date-block-formatting">
    <xsl:sequence select="maf:date-header-font()" />
    <xsl:attribute name="padding-bottom">0.25em</xsl:attribute>
    <xsl:attribute name="border-bottom-width">2pt</xsl:attribute>
    <xsl:attribute name="border-bottom-style">solid</xsl:attribute>
  </xsl:function>
  
  <xsl:function name="maf:date-inline-formatting">
  </xsl:function>
  
  <xsl:function name="maf:summary-block-formatting">
    <xsl:sequence select="maf:summary-font()" />
    <xsl:attribute name="border-bottom-width">1pt</xsl:attribute>
    <xsl:attribute name="border-bottom-style">solid</xsl:attribute>
    <xsl:attribute name="background-color">#f3f3f3</xsl:attribute>
  </xsl:function>

  <xsl:function name="maf:summary-inner-block-formatting">
    <xsl:attribute name="margin-top">0.5em</xsl:attribute>
    <xsl:attribute name="margin-bottom">0.5em</xsl:attribute>
    <xsl:attribute name="margin-left">1em</xsl:attribute>
    <xsl:attribute name="margin-right">1em</xsl:attribute>
    <xsl:attribute name="text-align">justify</xsl:attribute>
  </xsl:function>
  
  <xsl:function name="maf:main-block-formatting">
    <xsl:sequence select="maf:main-font()" />
    <xsl:attribute name="space-before">1em</xsl:attribute>
    <xsl:attribute name="space-after">2em</xsl:attribute>
    <xsl:attribute name="text-align">justify</xsl:attribute>
  </xsl:function>
  
  <xsl:function name="maf:text-para-formatting">
    <xsl:attribute name="space-after">1em</xsl:attribute>
    <xsl:attribute name="text-align">justify</xsl:attribute>
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
          margin-top="0.25in"
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
    <fo:block keep-together="1">
      <fo:block>
        <xsl:sequence select="maf:date-block-formatting()" />
        <fo:inline>
          <xsl:sequence select="maf:date-inline-formatting()" />
          <xsl:value-of select="format-date(xs:date(@date), '[F], [MNn] [D], [Y]')" />
        </fo:inline>
      </fo:block>
      
      <!-- Don't render the summary at all unless it has content -->
      <xsl:if test="exists(summary/(text()|*))">
        <fo:block>
          <xsl:sequence select="maf:summary-block-formatting()" />
          <fo:block>
            <xsl:sequence select="maf:summary-inner-block-formatting()" />
            <xsl:apply-templates mode="#current" select="summary/(text()|*)" />
          </fo:block>
        </fo:block>
      </xsl:if>
    </fo:block>
    <fo:block keep-with-previous="1">
      <xsl:sequence select="maf:main-block-formatting()" />
      <xsl:apply-templates select="text/p" />
    </fo:block>
  </xsl:template>
  
  
  <xsl:template match="summary|p">
    <fo:block>
      <xsl:sequence select="maf:text-para-formatting()" />
      <xsl:apply-templates select="text()|*" />
    </fo:block>
  </xsl:template>
    
  <!-- catchall for unhandled elements: copy text and children -->
  <xsl:template match="element()">
    <xsl:copy>
      <xsl:apply-templates mode="#current" select="text()|*" />
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="i">
    <fo:inline font-style="italic"><xsl:apply-templates select="text()|*" /></fo:inline>
  </xsl:template>
  
  <xsl:template match="b">
    <fo:inline font-weight="bold"><xsl:apply-templates select="text()|*" /></fo:inline>
  </xsl:template>
  
  
  <!-- format month header -->
  <xsl:function name="maf:format-month-year" as="xs:string">
    <xsl:param name="month" as="xs:string" />
    <xsl:param name="year" as="xs:string" />
    
    <xsl:variable name="first" as="xs:date" select="xs:date(concat($year, '-', $month, '-01'))" />
    <xsl:value-of select="format-date($first, '[MNn] [Y]')" />
  </xsl:function>
</xsl:stylesheet>
