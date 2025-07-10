<#macro kw>
  <#switch message.type>
    <#case "error">
      <#assign color="alert-red" logo="circle-alert">
      <#break>
    <#case "info">
      <#assign color="bg-blue-100 text-blue-600" logo="circle-check">
      <#break>
    <#case "success">
      <#assign color="alert-green" logo="circle-check">
      <#break>
    <#case "warning">
      <#assign color="alert-yellow" logo="circle-warning">
      <#break>
    <#default>
      <#assign color="bg-blue-100 text-blue-600" logo="circle-check">
  </#switch>

  <#--  會過濾一些不想顯示的文案  -->
  <#if message.summary != msg("updatePasswordMessage")>
  <div class="${color} alert-block p-4 rounded-lg text-sm" role="alert">
    <div class="${logo} alert-block-logo"></div>
    <span>${kcSanitize(message.summary)?no_esc}</span>
  </div>
  </#if>
</#macro>
