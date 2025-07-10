<#macro kw invalid name autofocus=false disabled=false message=true required=false toggleCleanAll=false togglePasswordHiden=false inputId=' ' rest...>
  <label class="sr-only" for="${name}">
    <#nested>
  </label>
  <div class="p-r">
    <script>
      function showPwdRuleTooltip(inputId) {
        const input = document.getElementById(inputId);
  
        if(!input) return;
  
        if (input.id == 'passwordNew') {
          const pwdRuleTooltip = document.getElementById('pwdRuleTooltip');
          pwdRuleTooltip.classList.add('show-pwd-rule-tooltip');
        }
      }
    </script>
    <input
      <#if inputId = 'passwordNew'>
      onfocus="showPwdRuleTooltip('${inputId}')"
      onblur="hidePwdRuleToolTooltip('${inputId}')"
      </#if>

      <#if inputId != ' '>id=${inputId}</#if>
      <#if autofocus>autofocus</#if>
      <#if disabled>disabled</#if>
      <#if required>required</#if>
      aria-invalid="${messagesPerField.existsError(invalid)?c}"
      class="<#if messagesPerField.existsError(invalid)?c == 'true'>bc-red</#if> w-315 primary-input show-passwords block border-gray-300 mt-1 rounded-md w-full sm:text-sm"
      id="${name}"
      name="${name}"
      placeholder="<#compress><#nested></#compress>"
      <#list rest as attrName, attrValue>
        ${attrName}="${attrValue}"
      </#list>
    >

    <#--  顯示密碼規則的tooltip  if似乎沒作用-->
    <#if inputId == 'passwordNew'>
    <span id="pwdRuleTooltip" class="pwd-rule-tooltip <#if messagesPerField.existsError(invalid)>show-pwd-rule-tooltip</#if>">${kcSanitize(msg("pwdRule"))?no_esc}</span>
    </#if>

    <#if toggleCleanAll>
      <svg class="clean-all-text-button svgHover" onclick="cleanInput('${inputId}')" width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
        <g clip-path="url(#clip0_15_28)">
          <path d="M8.00008 0.666656C3.93341 0.666656 0.666748 3.93332 0.666748 7.99999C0.666748 12.0667 3.93341 15.3333 8.00008 15.3333C12.0667 15.3333 15.3334 12.0667 15.3334 7.99999C15.3334 3.93332 12.0667 0.666656 8.00008 0.666656ZM12.0001 10.6667L10.6667 12L8.00008 9.33332L5.33341 12L4.00008 10.6667L6.66675 7.99999L4.00008 5.33332L5.33341 3.99999L8.00008 6.66666L10.6667 3.99999L12.0001 5.33332L9.33341 7.99999L12.0001 10.6667Z" fill="black"/>
        </g>
        <defs>
          <clipPath id="clip0_15_28">
            <rect width="16" height="16" fill="white"/>
          </clipPath>
        </defs>
      </svg>
    </#if>

    <#if togglePasswordHiden>
      <svg id="hide-pwd-${inputId}" class="hide-password-button svgHover" onclick="toggleShowPasswordInput('${inputId}')" width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path fill-rule="evenodd" clip-rule="evenodd" d="M0 8.00001C0.933333 4.13334 4.13333 1.33334 8 1.33334C11.8667 1.33334 15.0667 4.13334 16 8.00001C15.0667 11.8667 11.8667 14.6667 8 14.6667C4.13333 14.6667 0.933333 11.8667 0 8.00001ZM4.66667 8.00001C4.66667 9.86668 6.13333 11.3333 8 11.3333C9.86667 11.3333 11.3333 9.86668 11.3333 8.00001C11.3333 6.13334 9.86667 4.66668 8 4.66668C6.13333 4.66668 4.66667 6.13334 4.66667 8.00001ZM9.33333 8.00001C9.33333 8.73639 8.73638 9.33334 8 9.33334C7.26362 9.33334 6.66667 8.73639 6.66667 8.00001C6.66667 7.26363 7.26362 6.66668 8 6.66668C8.73638 6.66668 9.33333 7.26363 9.33333 8.00001Z" fill="black"/>
      </svg>
      <svg id="show-pwd-${inputId}" class="show-password-button svgHover" onclick="toggleShowPasswordInput('${inputId}')" width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path fill-rule="evenodd" clip-rule="evenodd" d="M8 11.3333C6.13333 11.3333 4.66667 9.86665 4.66667 7.99998C4.66667 6.13331 6.13333 4.66665 8 4.66665C9.86667 4.66665 11.3333 6.13331 11.3333 7.99998C11.3333 8.19998 11.3333 8.46665 11.2666 8.66665C11.7999 8.46665 12.4 8.33331 13 8.33331C14 8.33331 14.8667 8.66665 15.6667 9.13332C15.6939 9.05168 15.7211 8.97282 15.7477 8.8956L15.7478 8.89554C15.8517 8.59444 15.9469 8.31832 16 7.99998C15.0667 4.13331 11.8667 1.33331 8 1.33331C4.13333 1.33331 0.933333 4.13331 0 7.99998C0.933333 11.8666 4.13333 14.6666 8 14.6666H8.66667C8.46667 14.1333 8.33333 13.6 8.33333 13C8.33333 12.4 8.46667 11.8 8.66667 11.2667C8.46672 11.3333 8.20013 11.3333 8.00015 11.3333H8ZM8 9.33331C8.73638 9.33331 9.33333 8.73636 9.33333 7.99998C9.33333 7.2636 8.73638 6.66665 8 6.66665C7.26362 6.66665 6.66667 7.2636 6.66667 7.99998C6.66667 8.73636 7.26362 9.33331 8 9.33331ZM13 11.6666L14.6667 9.99998L16 11.3333L14.3333 13L16 14.6666L14.6667 16L13 14.3333L11.3333 16L10 14.6666L11.6667 13L10 11.3333L11.3333 9.99998L13 11.6666Z" fill="black"/>
      </svg>
    </#if>
  </div>
  <#if message && messagesPerField.existsError(invalid)>
    <div class="mt-2 text-red-600 text-sm d-f">
      <img class="mr-5" src="${url.resourcesPath}/img/alert-sign.png">
      ${kcSanitize(messagesPerField.getFirstError(invalid))?no_esc}
    </div>
  </#if>
</#macro>
