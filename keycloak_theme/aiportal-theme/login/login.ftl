<#import "template.ftl" as layout>
<#import "components/provider.ftl" as provider>
<#import "components/button/primary.ftl" as buttonPrimary>
<#import "components/checkbox/primary.ftl" as checkboxPrimary>
<#import "components/input/primary.ftl" as inputPrimary>
<#import "components/label/username.ftl" as labelUsername>
<#import "components/link/primary.ftl" as linkPrimary>

<@layout.registrationLayout
  displayInfo=realm.password && realm.registrationAllowed && !registrationDisabled??
  displayMessage=!messagesPerField.existsError("username", "password")
  ;
  section
>
  <#if section="header">
    <img src="${url.resourcesPath}/img/logoV3.png" alt="Logo" style="display: block; margin: 0 auto 10px auto; width: 220px;" style="margin-top:20px">
    <h2 class="subtitle fw-b text-center text-xl flex items-center justify-center" style="font-size: 1.75rem; margin-bottom: 15px;">
      ${msg("welcome")}
    </h2>
    <h4 class="fs-7 mb-5 fw-normal text-dark text-center" style="margin-bottom: 40px;">
      ${msg("signInToContinueFFM_Hub")}
    </h4>
  <#elseif section="form">
    <#if realm.password>
      <form
        action="${url.loginAction}"
        class="login-form m-0"
        method="post"
        onsubmit="return checkRequiredInput('password')"
      >
        <input
          name="credentialId"
          type="hidden"
          value="<#if auth.selectedCredential?has_content>${auth.selectedCredential}</#if>"
        >
        <div class="fw-b fs-14 mr-a">
        </div>
        <div>
          <@inputPrimary.kw
            inputId="usernameInput"
            autocomplete=realm.loginWithEmailAllowed?string("email", "username")
            autofocus=true
            disabled=usernameEditDisabled??
            invalid=["username", "password"]
            name="username"
            type="text"
            value=(login.username)!''
            style="height: 50px; margin-bottom: 15px;"
          >
            <@labelUsername.kw />
          </@inputPrimary.kw>
        </div>
        <div>
          <@inputPrimary.kw
            inputId="password"
            invalid=["username", "password"]
            message=false
            name="password"
            type="password"
            togglePasswordHiden=true
            style="height: 50px;"
          >
            ${msg("password")}
          </@inputPrimary.kw>
        </div>
        <div class="pt-10 login-user">
          <div class="fw-b fs-14 mr-a">
          </div>
          <div class="ml-a">
            <#if realm.resetPasswordAllowed>
              <@linkPrimary.kw href=url.loginResetCredentialsUrl>
                <span class="text-sm fs-14 text-underline color-black" style="color: #286fd9;
                ">${msg("doForgotPassword")}</span>
              </@linkPrimary.kw>
            </#if>
          </div>
        </div>
        <div class="v-h mr-a pt-10 pb-10 d-f" id="requiredAlert">
          <img src="${url.resourcesPath}/img/alert-sign.png">
          <h1 class="required-alert fs-10 pl-5">${msg("input.required")}</h1>
        </div>
        <div class="login-check-box flex items-center">
          <#if realm.rememberMe && !usernameEditDisabled??>
            <@checkboxPrimary.kw checked=login.rememberMe?? name="rememberMe">
              ${msg("rememberMe")}
            </@checkboxPrimary.kw>
          </#if>
        </div>
        <div>
          <@buttonPrimary.kw name="login" type="submit" buttonId="loginButton" disabled=true>
            ${msg("doLogIn")}
          </@buttonPrimary.kw>
        </div>
      </form>
    </#if>
  </#if>
</@layout.registrationLayout>
