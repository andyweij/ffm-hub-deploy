<#import "../icon/chevron-down.ftl" as iconChevronDown>
<#import "../link/secondary.ftl" as linkSecondary>

<#macro kw containerClass="" textClass="" dropDownClass="">
  <div class="relative ${containerClass} locale-buttom" x-data="{open: false}">
    <@linkSecondary.kw component="button" type="button" @click="open = true">
      <div class="flex items-center">
        <span class="color-black mr-1 text-sm ${textClass}">${locale.current}</span>
        <@iconChevronDown.kw />
      </div>
    </@linkSecondary.kw>
    <div
      class="${dropDownClass} locales-drop absolute bg-white -left-4 max-h-80 rounded-lg shadow-lg"
      x-show="open"
      @click.away="open = false"
    >
      <#list locale.supported as locales>
        <#if locale.current != locales.label>
          <div class="px-4 py-2 locales" class="h-40">
            <@linkSecondary.kw href=locales.url>
              <span class="text-sm" class="fs-16">${locales.label}</span>
              <script>
                // 因為剛轉進登入頁的網址不把語系參數放入cookie 所以用選擇語系的網址再轉導一次
                console.log('${locales.url}');
                var originalUrl = '${locales.url}';
                var urlLocale = new URLSearchParams(window.location.href).get('ui_locales');
                
                if (urlLocale) {
                  var protocol = window.location.protocol;
                  var host = window.location.host;
                  var relativeUrl = originalUrl.replace(/&amp;/g, '&').replace(/&?kc_locale=[^&]*&?/, '');
                  var absoluteUrl = protocol + '//' + host + relativeUrl + '&kc_locale=' + urlLocale;

                  console.log('absoluteUrl: '+absoluteUrl);
                  window.location.href = absoluteUrl;
                }
              </script>
            </@linkSecondary.kw>
          </div>
        </#if>
      </#list>
    </div>
  </div>
</#macro>