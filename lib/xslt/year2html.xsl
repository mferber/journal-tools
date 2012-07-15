<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:maf="http://www.matthiasferber.net/xmlns"
  
  exclude-result-prefixes="#all"
>
  <xsl:output method="html" use-character-maps="html" encoding="UTF-8"
    indent="yes"
  />
  
  <xsl:character-map name="html">
    <xsl:output-character character="&#x2014;" string="&amp;mdash;" />
  </xsl:character-map>
  
  <xsl:param name="input-base-uri" as="xs:anyURI" required="yes" />
  <xsl:param name="year" as="xs:integer" required="yes" />
  
  <xsl:variable name="month-abbrs" as="xs:string*"
    select="('Jan.', 'Feb.', 'March', 'April', 'May', 'June', 'July',
      'Aug.', 'Sept.', 'Oct.', 'Nov.', 'Dec.')"
  />

  <xsl:variable name="weekdays" as="xs:string*"
    select="('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
      'Saturday')"
  />

  <xsl:variable name="one-day" as="xs:dayTimeDuration"
    select="xs:dayTimeDuration('P1D')"
  />
  
  <xsl:template name="main">
    <xsl:variable name="yearjournal" as="element(summaries)">
      <summaries>
        <xsl:for-each select="$month-abbrs">
          <xsl:variable name="yr-month"
            select="concat($year, '-', format-number(position(), '00'))"
          />
          <xsl:variable name="month-xml-uri"
            select="resolve-uri(concat($yr-month, '.xml'), $input-base-uri)"
          />
          <xsl:if test="doc-available($month-xml-uri)">
            <xsl:for-each select="document($month-xml-uri)/journal/entry/summary">
              <summary date="{../@date}" weekday="{../@weekday}"
                weekdaynum="{(((index-of($weekdays, ../@weekday))[1] - 1) mod 7) + 1}"
              >
                <xsl:if test="exists(../text)">
                  <xsl:attribute name="has-text" select="'yes'" />
                </xsl:if>
                <xsl:sequence select="*|text()" />
              </summary>
            </xsl:for-each>
          </xsl:if>
        </xsl:for-each>
      </summaries>
    </xsl:variable>
    
    <xsl:apply-templates select="$yearjournal" />
  </xsl:template>
  
  <xsl:template match="summaries">
    <html>
      <head>
        <title>Journal: Calendar</title>
        <link rel="stylesheet" href="css/calendar.css" />
      </head>
      <body>
        <table class="cal">
          <thead>
            <tr class="weekday-header">
              <xsl:for-each select="$weekdays">
                <th><xsl:value-of select="." /></th>
              </xsl:for-each>
            </tr>
          </thead>
          
          <tbody>
            <xsl:for-each-group select="maf:calendar-pad-week(summary)"
              group-ending-with="summary[@weekdaynum eq '7']"
            >
              <tr>
                <xsl:for-each 
                  select="1 to xs:integer(current-group()[1]/@weekdaynum) - 1"
                >
                  <xsl:variable name="weekdaynum" select="xs:integer(.)" />
                  <td class="weekday-{$weekdays[$weekdaynum]} placeholder" />
                </xsl:for-each>
                <xsl:apply-templates select="current-group()" mode="#current" />
                <xsl:for-each
                  select="xs:integer(current-group()[last()]/@weekdaynum) + 1 to 7"
                >
                  <xsl:variable name="weekdaynum" select="xs:integer(.)" />
                  <td class="weekday-{$weekdays[$weekdaynum]} empty" />
                </xsl:for-each>
              </tr>
            </xsl:for-each-group>
          </tbody>
        </table>
      </body>
    </html>
  </xsl:template>
  
  <xsl:template match="summary">
    <td>
      <xsl:attribute name="class" select="
        concat('weekday-', @weekday,
          if (@empty eq 'yes') then ' empty' else ''
        )
      "/>
      <div class="date">
        <xsl:variable name="disp-date" as="xs:string" 
          select="format-date(xs:date(@date), '[MNn] [D], [Y]')"
        />

        <xsl:value-of select="$disp-date" />
        <xsl:if test="@has-text eq 'yes'">
          <span class="more-icon">
            <a href="{concat(format-date(xs:date(@date), '[Y0001]-[M01]'), '.html#',
              @date)}"
            >
              &gt;
            </a>
          </span>
        </xsl:if>
      
      </div>
      <div class="summary">
        <xsl:if test="exists(text()|*)">
          <xsl:apply-templates mode="#current" select="text()|*" />
        </xsl:if>
      </div>
    </td>
  </xsl:template>



  <!-- Pad out a week of entries with empty entries for missing days -->
  <xsl:function name="maf:calendar-pad-week" as="element(summary)*">
    <xsl:param name="summaries" as="element(summary)*" />
    <xsl:for-each select="$summaries">
    
      <!-- if the preceding entry is not from the preceding date, add
        empty filler entries -->
      <xsl:if test="exists(preceding-sibling::summary)">
        <xsl:variable name="cur-date" as="xs:date"
          select="xs:date(@date)"
        />
        <xsl:variable name="prev-date" as="xs:date"
          select="xs:date(preceding-sibling::summary[1]/@date)"
        />
        <xsl:variable name="prev-weekday" as="xs:integer"
          select="preceding-sibling::summary[1]/@weekdaynum" 
        />
        <xsl:for-each select="1 to days-from-duration($cur-date - $prev-date) - 1">
          <xsl:variable name="weekdaynum" as="xs:integer"
            select="(($prev-weekday - 1 + .) mod 7) + 1"
          />
          <summary 
            date="{$prev-date + ($one-day * .)}"
            weekday="{$weekdays[$weekdaynum]}"
            weekdaynum="{$weekdaynum}"
            empty="yes" 
          />
        </xsl:for-each>
      </xsl:if>

      <xsl:sequence select="." />
    </xsl:for-each>
  </xsl:function>  

</xsl:stylesheet>