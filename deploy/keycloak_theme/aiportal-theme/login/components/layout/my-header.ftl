<#import "../link/primary.ftl" as linkPrimary>
<#import "locales.ftl" as locales>
<#import "../link/secondary.ftl" as linkSecondary>
<#macro kw>
  <div class="my-header">
    <div class="f-l">
      <@linkSecondary.kw href=url.loginUrl>
      </@linkSecondary.kw>
    </div>
    <#--  <div id="localesRegistration" class="locales-registration">
      <#if realm.internationalizationEnabled && locale.supported?size gt 1>
        <@locales.kw containerClass="mr-a header-locale" textClass="fw-b" />
      </#if>
      <#if realm.password && realm.registrationAllowed && !registrationDisabled??>
        <button type="button" style="height: 38px; width: 74px; float: right; background-color: #00A4A9;" class="mt-a mb-a mr-a primary-button rounded-lg">
          <@linkPrimary.kw href=url.loginUrl style="color:white; font-size: 16px; display: inline-block;">
            ${msg("doLogIn")}
          </@linkPrimary.kw>
        </button>
      </#if>
    </div>  -->
  </div>
</#macro>