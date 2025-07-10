<#macro kw component="a" linkClass="" rest...>
  <${component}
    class="${linkClass} flex text-secondary-600 hover:text-secondary-900"
    <#list rest as attrName, attrValue>
      ${attrName}="${attrValue}"
    </#list>
  >
    <#nested>
  </${component}>
</#macro>
