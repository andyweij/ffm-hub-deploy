<#import "../link/primary.ftl" as linkPrimary>
<#import "locales.ftl" as locales>

<#assign realmName=url.loginUrl?split('/')[2]>
<#macro kw>
  <div class="my-footer">
    <div class="f-r d-f w-fit">
      <#--  <div>
        <#if realm.internationalizationEnabled && locale.supported?size gt 1>
          <@locales.kw dropDownClass="b-100" />
        </#if>
      </div>  -->
    </div>
  </div>
</#macro>