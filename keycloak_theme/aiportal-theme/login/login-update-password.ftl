<#import "template.ftl" as layout>
<#import "components/button/primary.ftl" as buttonPrimary>
<#import "components/input/primary.ftl" as inputPrimary>

<@layout.registrationLayout
  displayMessage=!messagesPerField.existsError("password", "password-confirm")
  ;
  section
>
  <#if section="header">
    ${msg("updatePasswordTitle")}
  <#elseif section="form">
    <form action="${url.loginAction}" class="m-0" method="post" onsubmit="return checkRequiredInput('passwordConfirm')">
      <input
        autocomplete="username"
        name="username"
        type="hidden"
        value="${username}"
      >
      <input autocomplete="current-password" name="password" type="hidden">
      <div class="fw-b fs-14 mr-a">
        ${msg("passwordNew")}
      </div>
      <div>
        <@inputPrimary.kw
          autocomplete="new-password"
          autofocus=true
          invalid=["password", "password-confirm"]
          message=false
          name="password-new"
          type="password"
          toggleCleanAll=true
          togglePasswordHiden=true
          inputId="passwordNew"
        >
          ${msg("passwordNew")}
        </@inputPrimary.kw>
      </div>
      <div class="pt-10 fw-b fs-14 mr-a">
        ${msg("passwordConfirm")}
      </div>
      <div>
        <@inputPrimary.kw
          autocomplete="new-password"
          invalid=["password-confirm"]
          name="password-confirm"
          type="password"
          toggleCleanAll=true
          togglePasswordHiden=true
          inputId="passwordConfirm"
        >
          ${msg("passwordConfirm")}
        </@inputPrimary.kw>
      </div>
      <div class="v-h pt-10 pb-10 d-f" id="requiredAlert">
        <img src="${url.resourcesPath}/img/alert-sign.png">
        <h1 class="required-alert fs-10 pl-5">${msg("input.required")}</h1>
      </div>
      <div>
        <@buttonPrimary.kw buttonId="passwordNewSubmit" disabled=true type="submit">
          ${msg("doLogIn")}
        </@buttonPrimary.kw>
      </div>
    </form>
  </#if>
</@layout.registrationLayout>
