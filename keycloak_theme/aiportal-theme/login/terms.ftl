<#import "template.ftl" as layout>
<#import "components/link/primary.ftl" as linkPrimary>
<#import "components/link/secondary.ftl" as linkSecondary>

<#assign realmName=url.loginUrl?split('/')[2]>

<@layout.registrationLayout displayMessage=false; section>
    <body onload="termsPageStyleChange('url(${url.resourcesPath}/img/background-start-using.png)');">
        <#if section = "header">
            ${msg("termsTitle")}
        <#elseif section = "form">
        <div id="kc-terms-text" style="width: 50vw;">
            ${kcSanitize(msg("termsText"))?no_esc} 
            ${msg("termsExplain", realmName)?no_esc}
        </div>
        <form class="form-actions d-c" action="${url.loginAction}" method="POST">
            <button type="submit" class="mt-a mb-a mr-a primary-button rounded-lg start-using-buttom ${properties.kcButtonClass!} ${properties.kcButtonPrimaryClass!} ${properties.kcButtonLargeClass!}">${msg("termsAccept")}</button>
        </form>
        <@linkSecondary.kw href=url.loginUrl linkClass="d-c">
            <span class="mr-a text-underline fs-12 mt-10">${msg("termsDecline")}</span>
        </@linkSecondary.kw>
        <div class="clearfix"></div>
        </#if>
    </body>
</@layout.registrationLayout>