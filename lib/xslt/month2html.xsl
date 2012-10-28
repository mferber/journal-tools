<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  
  exclude-result-prefixes="#all"
>
  <xsl:output method="html" use-character-maps="html" encoding="UTF-8" indent="yes"/>
  
  <xsl:character-map name="html">
    <xsl:output-character character="&#x2014;" string="&amp;mdash;" />
  </xsl:character-map>
  
  <xsl:variable name="month-names" as="xs:string*"
    select="('January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December')"
  />
  
  <!--
    Parse out month and year from the current filename; use to construct
    title and next/prev-month links
  -->
  <xsl:variable name="year-month" as="xs:string">
    <xsl:analyze-string select="document-uri(.)"
      regex="^.*(\d\d\d\d-\d\d)\.xml$"
    >
      <xsl:matching-substring>
        <xsl:value-of select="regex-group(1)" />
      </xsl:matching-substring>
    </xsl:analyze-string>
  </xsl:variable>
  <xsl:variable name="year-month-parts" as="xs:string*"
    select="tokenize($year-month, '-')"
  />
  <xsl:variable name="year" as="xs:integer"
    select="xs:integer($year-month-parts[1])"
  />
  <xsl:variable name="month" as="xs:integer"
    select="xs:integer($year-month-parts[2])"
  />
  <xsl:variable name="title" as="xs:string"
    select="concat($month-names[$month], ' ', $year)"
  />
  <xsl:variable name="next-month-reluri" as="xs:string">
    <xsl:variable name="y" select="if ($month eq 12) then $year+1 else $year" />
    <xsl:variable name="m" select="if ($month eq 12) then 1 else $month+1" />
    <xsl:value-of
      select="concat($y, '-', format-number($m, '00'), '.html')"
    />
  </xsl:variable>
  <xsl:variable name="prev-month-reluri" as="xs:string">
    <xsl:variable name="y" select="if ($month eq 1) then $year - 1 else $year" />
    <xsl:variable name="m" select="if ($month eq 1) then 12 else $month - 1" />
    <xsl:value-of
      select="concat($y, '-', format-number($m, '00'), '.html')"
    />
  </xsl:variable>
  
  
  <xsl:template match="/">
    <html>
      <head>
        <title>Journal: <xsl:value-of select="$title" /></title>
        <link rel="stylesheet" href="css/fulltext.css" />
      </head>
      <body>
        <h1 class="month-header">
          <a class="month-header-link" href="{$prev-month-reluri}">&lt;</a>
          <xsl:text>&#160;</xsl:text>
          <xsl:value-of select="$title" />
          <xsl:text>&#160;</xsl:text>
          <a class="month-header-link" href="{$next-month-reluri}">&gt;</a>
        </h1>
        <xsl:apply-templates mode="#current" select="journal/entry" />
        <h2 class="month-footer">
          <a class="month-footer-link" href="{$next-month-reluri}">
            Continue to
            <xsl:value-of select="
              $month-names[if ($month eq 12) then 1 else $month+1]
            "/>
          </a>
        </h2>
      </body>
    </html>
  </xsl:template>
  
  <xsl:template match="entry">
    <a name="{@date}" />
    <div class="entry">
      <div class="date">
        <xsl:value-of select="format-date(xs:date(@date), '[F], [MNn] [D1o], [Y]')" />
      </div>
      <xsl:apply-templates mode="#current" />
    </div>
  </xsl:template>
  
  <xsl:template match="summary">
    <div class="summary">
      <xsl:apply-templates mode="#current" select="p/(*|text())" />
    </div>
  </xsl:template>
  
  <xsl:template match="element()">
    <xsl:copy>
      <xsl:apply-templates mode="#current" select="text()|*" />
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="text">
    <div class="text">
      <xsl:apply-templates mode="#current" />
    </div>
  </xsl:template>
  
  <xsl:template match="p">
    <xsl:copy>
      <xsl:attribute name="class">para</xsl:attribute>
      <xsl:sequence select="text()|*" />
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
