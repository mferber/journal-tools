<?xml version="1.0" encoding="UTF-8"?>

<!--
  Parameters:
  
  This stylesheet can generate the calendar for a single year, or for an
  arbitrary date range.  (The latter option is there to allow for new
  pages to be added to an already-printed calendar, without dividing it
  into years.)
  
  Use one of the following parameter sets:
  
    year - integer - the year to generate the calendar for
  
  OR:
  
    start - xs:date - starting date
    end - xs:date - ending date (optional)
  
  In case of conflict, $year is used in precedence to $start/$end.
  
  If neither set of parameters is provided, the entire available date
  range will be used.
  
-->
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:maf="http://www.matthiasferber.net/xmlns"
  xmlns:fo="http://www.w3.org/1999/XSL/Format"
  
  exclude-result-prefixes="xsl xs maf"
>
  <xsl:output indent="yes"/>

  <!--
    params are type string because that seems to be the only type
    FOP is capable of passing via the -param option to the fop command
    line tool, probably because it expects an XSLT 1.0 processor
  -->
  <xsl:param name="year" as="xs:string" select="''" required="no" />
  <xsl:param name="start" as="xs:string" select="''" required="no" />
  <xsl:param name="end" as="xs:string" select="''" required="no" />
  <xsl:param name="input-base-uri" as="xs:string" required="yes" />
  
  <xsl:variable name="yearint" as="xs:integer" select="
    if ($year castable as xs:integer) then xs:integer($year) else -1
  "/>
  <xsl:variable name="startdate" as="xs:date" select="
    if ($start castable as xs:date) then xs:date($start)
      else xs:date('1990-01-01')
  "/>
  <xsl:variable name="enddate" as="xs:date" select="
    if ($end castable as xs:date) then xs:date($end)
      else xs:date('2099-01-01')
  "/>
  
  <xsl:variable name="weekdays" as="xs:string*"
    select="('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
      'Saturday')"
  />
  
  <xsl:variable name="maf:one-day" as="xs:dayTimeDuration"
    select="xs:dayTimeDuration('P1D')"
  />
  
  
  <xsl:template match="/">
    <xsl:call-template name="main" />
  </xsl:template>
  
  
  <!--
    Main template: compute the range of months we need to cover, and
    locate and process all XML files for those months, outputting a
    <calendar-entries> document containing a <calendar-entry> for every
    day in the original XML
  -->
  <xsl:template name="main">
    <xsl:variable name="startyear" as="xs:integer" select="
      if ($yearint ne -1) then $yearint else year-from-date($startdate)
    "/>
    <xsl:variable name="startmonth" as="xs:integer" select="
      if ($yearint ne -1) then 1 else month-from-date($startdate)
    "/>
    <xsl:variable name="endyear" as="xs:integer" select="
      if ($yearint ne -1) then $yearint else year-from-date($enddate)
    "/>
    <xsl:variable name="endmonth" as="xs:integer" select="
      if ($yearint ne -1) then 12 else month-from-date($enddate)
    "/>
    
    <xsl:variable name="calendar-entries" as="element(calendar-entries)">
      <calendar-entries>
        <xsl:for-each select="$startyear to $endyear">
          <xsl:variable name="yr" as="xs:integer" select="." />
          
          <xsl:variable name="yrstartmonth" as="xs:integer"
            select="if ($yr eq $startyear) then $startmonth else 1"
          />
          <xsl:variable name="yrendmonth" as="xs:integer"
            select="if ($yr eq $endyear) then $endmonth else 12"
          />

          <xsl:if test="$yrstartmonth le $yrendmonth">

            <xsl:for-each select="$yrstartmonth to $yrendmonth">
              <xsl:variable name="month" select="." />
              
              <xsl:variable name="uri" as="xs:anyURI"
                select="resolve-uri(concat($yr, '-',
                  format-number($month, '00'), '.xml'),
                  $input-base-uri)"
              />
              
              <xsl:value-of select="'&#xa;'" />
              <xsl:comment select="$uri" />
              <xsl:value-of select="'&#xa;'" />
  
              <xsl:choose>
                <xsl:when test="doc-available($uri)">
                  <xsl:for-each
                    select="document($uri)/journal/entry/summary"
                  >
                    <xsl:variable name="date" as="xs:date" select="../@date" />
                    <xsl:if test="$date ge $startdate and $date le $enddate">
                      <xsl:variable name="weekdaynum" as="xs:integer"
                        select="
                          (((index-of($weekdays, ../@weekday))[1] - 1) mod 7)
                            + 1
                        "
                      />
                      <calendar-entry date="{../@date}" weekday="{../@weekday}"
                        weekdaynum="{$weekdaynum}"
                      >
                        <xsl:if test="../text">
                          <xsl:attribute name="has-body">yes</xsl:attribute>
                        </xsl:if>
                        <xsl:sequence select="*|text()" />
                      </calendar-entry>
                    </xsl:if>
                  </xsl:for-each>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:comment>Not found</xsl:comment>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:for-each>
            
          </xsl:if>
        </xsl:for-each>
      </calendar-entries>
    </xsl:variable>
    
    <!-- main FO output -->
    <fo:root>

      <fo:layout-master-set>
        <fo:simple-page-master
          master-name="main"
          page-height="8.5in"
          page-width="11in"
          margin-top="0.75in"
          margin-bottom="0.5in"
          margin-left="0.5in"
          margin-right="0.5in"
        >
          <fo:region-body />
        </fo:simple-page-master>
      </fo:layout-master-set>
    
      <fo:page-sequence master-reference="main">
        <fo:flow flow-name="xsl-region-body">
          <fo:block>
            <fo:table table-layout="fixed" width="100%">
              <xsl:sequence select="maf:full-border()" />
              
              <xsl:for-each select="1 to 7">
                <fo:table-column column-width="proportional-column-width(1)" />
              </xsl:for-each>
              
              <fo:table-header>
                <fo:table-row space-after="1em">
                  <xsl:for-each select="$weekdays">
                    <fo:table-cell>
                      <xsl:sequence select="maf:table-header-cell-formatting()" />
                      <fo:block><xsl:value-of select="." /></fo:block>
                    </fo:table-cell>
                  </xsl:for-each>
                </fo:table-row>
              </fo:table-header>
          
              <fo:table-body>
                <xsl:for-each-group
                  select="maf:calendar-pad-week(
                    $calendar-entries/calendar-entry)"
                  group-ending-with="calendar-entry[@weekdaynum eq '7']"
                >
                  <fo:table-row>

                    <!-- empty cell padding, initial row -->
                    <xsl:for-each
                      select="1 to
                        xs:integer(current-group()[1]/@weekdaynum) - 1
                      "
                    >
                      <fo:table-cell>
                        <xsl:sequence select="maf:full-border()" />
                        <fo:block></fo:block>
                      </fo:table-cell>
                    </xsl:for-each>
                    
                    <!-- cells with content -->
                    <xsl:apply-templates select="current-group()"
                      mode="#current"
                    />
                    
                    <!-- empty cell padding, final row -->
                    <xsl:for-each
                      select="
                        1 to
                        7 - xs:integer(current-group()[last()]/@weekdaynum)
                      "
                    >
                      <fo:table-cell>
                        <xsl:sequence select="maf:full-border()" />
                        <fo:block></fo:block>
                      </fo:table-cell>
                    </xsl:for-each>
                    
                  </fo:table-row>
                </xsl:for-each-group>
              </fo:table-body>
            </fo:table>
          </fo:block>
        </fo:flow>
      </fo:page-sequence>
    </fo:root>
  </xsl:template>


  <!--
    Convert a calendar entry to FO display objects
  -->
  <xsl:template match="calendar-entry">
    <fo:table-cell>
      <xsl:sequence select="maf:full-border()" />
      <xsl:if test="@weekday = ('1', '7')">
        <xsl:sequence select="maf:weekend-table-cell-formatting()" />
      </xsl:if>
      <fo:block keep-together="1">
        <fo:block>
          <xsl:sequence select="maf:date-block-formatting()" />
          <fo:inline>
            <xsl:sequence select="maf:date-inline-formatting()" />

            <!-- FOP seems to have trouble rendering special characters
              in Unicode even if the font has those characters.  Here are
              the ones I've tried:  ★☆♦⚫♱☛◼◉►◈⁕⁜⁂
              Only using the diamond symbol and coercing to the Symbol font
              has produced any success, but that also throws off the line
              height and makes these boxes higher when there's a bullet
              then when there isn't.  Scrapping it and using the available
              section symbol §.  The paragraph (pilcrow) char ¶ also works. -->
            <xsl:if test="@has-body eq 'yes'">
              <!--<fo:inline font-family="Symbol" font-weight="normal">♦ </fo:inline>-->
              <!--<fo:inline font-family="ITC Zapf Dingbats" font-weight="normal">★☆♦⚫♱☛◼◉►◈⁕⁜⁂ </fo:inline>-->
              <xsl:text>§ </xsl:text>
            </xsl:if>
            <xsl:value-of select="format-date(xs:date(@date), '[MNn] [D], [Y]')" />
          </fo:inline>
        </fo:block>
        <fo:block>
          <xsl:sequence select="maf:summary-block-formatting()" />
          <xsl:choose>
            <xsl:when test="not(@empty)">
              <xsl:apply-templates mode="#current" select="text()|*" />
            </xsl:when>
            <xsl:otherwise>
              <!-- Use padding to add a little extra space where the block is empty -->
              <!-- This shows up when an entire week has no summaries, and keeps the -->
              <!-- two rows of dates from being squashed too close together -->
              <fo:block padding-bottom="2mm" />
            </xsl:otherwise>
          </xsl:choose>
        </fo:block>
      </fo:block>
    </fo:table-cell>
  </xsl:template>
  
  
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
  
  
  <!--
    Pad out a week of entries with empty entries for missing days
  -->
  <xsl:function name="maf:calendar-pad-week" as="element(calendar-entry)*">
    <xsl:param name="entries" as="element(calendar-entry)*" />
    <xsl:for-each select="$entries">
    
      <!-- if the preceding entry is not from the preceding date, add
        empty filler entries -->
      <xsl:if test="exists(preceding-sibling::calendar-entry)">
        <xsl:variable name="cur-date" as="xs:date"
          select="xs:date(@date)"
        />
        <xsl:variable name="prev-date" as="xs:date"
          select="xs:date(preceding-sibling::calendar-entry[1]/@date)"
        />
        <xsl:variable name="prev-weekday" as="xs:integer"
          select="preceding-sibling::calendar-entry[1]/@weekdaynum" 
        />
        <xsl:for-each select="
          1 to days-from-duration($cur-date - $prev-date) - 1
        ">
          <xsl:variable name="weekdaynum" as="xs:integer"
            select="(($prev-weekday - 1 + .) mod 7) + 1"
          />
          <calendar-entry 
            date="{$prev-date + ($maf:one-day * .)}"
            weekdaynum="{$weekdaynum}"
            weekday="{$weekdays[$weekdaynum]}"
            empty="yes" 
          />
        </xsl:for-each>
      </xsl:if>

      <xsl:sequence select="." />
    </xsl:for-each>
  </xsl:function>  


  <!-- Attribute set functions -->
  
  <xsl:function name="maf:display-font">
    <xsl:attribute name="font-family">Helvetica</xsl:attribute>
    <xsl:attribute name="font-size">7pt</xsl:attribute>
    <xsl:attribute name="font-weight">bold</xsl:attribute>
  </xsl:function>
  
  <xsl:function name="maf:main-font">
    <xsl:attribute name="font-family">Georgia</xsl:attribute>
    <xsl:attribute name="font-size">7pt</xsl:attribute>
    <xsl:attribute name="font-weight">normal</xsl:attribute>
  </xsl:function>
  
  <xsl:function name="maf:full-border">
    <xsl:attribute name="border-before-width">1pt</xsl:attribute>
    <xsl:attribute name="border-before-style">solid</xsl:attribute>
    <xsl:attribute name="border-after-width">1pt</xsl:attribute>
    <xsl:attribute name="border-after-style">solid</xsl:attribute>
    <xsl:attribute name="border-start-width">1pt</xsl:attribute>
    <xsl:attribute name="border-start-style">solid</xsl:attribute>
    <xsl:attribute name="border-end-width">1pt</xsl:attribute>
    <xsl:attribute name="border-end-style">solid</xsl:attribute>
  </xsl:function>
  
  <xsl:function name="maf:table-header-cell-formatting">
    <xsl:sequence select="maf:full-border()" />
    <xsl:sequence select="maf:display-font()" />
    <xsl:attribute name="text-align">center</xsl:attribute>
    <xsl:attribute name="background-color">#333</xsl:attribute>
    <xsl:attribute name="color">white</xsl:attribute>
    <xsl:attribute name="padding-top">1mm</xsl:attribute>
    <xsl:attribute name="padding-bottom">1mm</xsl:attribute>
  </xsl:function>
  
  <xsl:function name="maf:date-block-formatting">
    <xsl:sequence select="maf:display-font()" />
    <xsl:attribute name="text-align">right</xsl:attribute>
    <xsl:attribute name="background-color">#e8e8e8</xsl:attribute>
    <xsl:attribute name="padding-top">1mm</xsl:attribute>
    <xsl:attribute name="padding-bottom">1mm</xsl:attribute>
    <xsl:attribute name="border-bottom-style">solid</xsl:attribute>
    <xsl:attribute name="border-bottom-width">0.25pt</xsl:attribute>
  </xsl:function>
  
  <xsl:function name="maf:date-inline-formatting">
    <xsl:attribute name="padding-right">1mm</xsl:attribute>
  </xsl:function>
  
  <xsl:function name="maf:summary-block-formatting">
    <xsl:sequence select="maf:main-font()" />
    <xsl:attribute name="margin-top">1mm</xsl:attribute>
    <xsl:attribute name="margin-bottom">1mm</xsl:attribute>
    <xsl:attribute name="margin-left">1mm</xsl:attribute>
    <xsl:attribute name="margin-right">1mm</xsl:attribute>
  </xsl:function>
  
  <xsl:function name="maf:weekend-table-cell-formatting">
    <xsl:attribute name="background-color">#f8f8f8</xsl:attribute>
  </xsl:function>
  
  
</xsl:stylesheet>