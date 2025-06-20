<#import "template.ftl" as layout>
<#import "components/button/primary.ftl" as buttonPrimary>
<#import "components/input/primary.ftl" as inputPrimary>
<#import "components/label/username.ftl" as labelUsername>
<#import "components/link/secondary.ftl" as linkSecondary>
<#import "components/link/primary.ftl" as linkPrimary>

<@layout.registrationLayout
  displayInfo=true
  displayMessage=!messagesPerField.existsError("username")
  ;
  section
>
  <#if section="header">
    ${msg("emailForgotTitle")}
  <#elseif section="form">

    <form action="${url.loginAction}" class="m-0 space-y-4" method="post">
      <div class="reset-pwd pt-10">
        <div class="fw-b fs-14 mr-a">
        ${msg("username")}
        </div>
        <div class="ml-a">
          <@linkPrimary.kw href=url.loginUrl>
            <span class="text-sm fs-14 text-underline color-black">${msg("backToLogin")}</span>
          </@linkPrimary.kw>
        </div>
      </div>

      <div class="m-u">
        <@inputPrimary.kw
          inputId="forgetPwdInput"
          autocomplete=realm.loginWithEmailAllowed?string("email", "username")
          autofocus=true
          invalid=["username"]
          name="username"
          type="text"
          value=(auth?has_content && auth.showUsername())?then(auth.attemptedUsername, '')
        >
          <@labelUsername.kw />
        </@inputPrimary.kw>
      </div>

      <div class="fs-14">
        ${msg("emailInstruction")}
      </div>

      <div>
        <@buttonPrimary.kw type="submit" buttonId="forgetPwdSubmit" disabled=true>
          ${msg("doSubmit")}
        </@buttonPrimary.kw>
      </div>
    </form>
  </#if>
</@layout.registrationLayout>
