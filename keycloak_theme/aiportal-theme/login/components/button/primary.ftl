<#macro kw component="button" buttonId=' ' disabled=false rest...>
  <${component}
    <#if buttonId != ' '>id=${buttonId}</#if>
    <#if disabled>disabled</#if>
    class="primary-button flex justify-center px-4 py-2 relative rounded-lg text-sm text-white focus:outline-none focus:ring-2"
    <#list rest as attrName, attrValue>
      ${attrName}="${attrValue}"
    </#list>
  >
    <#nested>
  </${component}>
</#macro>
