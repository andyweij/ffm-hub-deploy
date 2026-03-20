function toggleShowPasswordInput(inputId) {
  const passwordInput = document.getElementById(inputId);
  const hidePwd = document.getElementById(`hide-pwd-${inputId}`);
  const showPwd = document.getElementById(`show-pwd-${inputId}`);

  if (passwordInput.type === 'password') {
    passwordInput.type = 'text';
    hidePwd.style.display = 'none';
    showPwd.style.display = 'block';
  } else if (passwordInput.type === 'text') {
    passwordInput.type = 'password';
    hidePwd.style.display = 'block';
    showPwd.style.display = 'none';
  }
}

function checkRequiredInput(inputId) {
  const requiredInput = document.getElementById(inputId);
  const requiredAlert = document.getElementById('requiredAlert');

  if (requiredInput.value.trim() === '') {
    requiredAlert.style.visibility = 'visible';
    requiredInput.classList.add('bc-red');
    return false;
  } else {
    requiredAlert.style.visibility = 'hidden';
    requiredInput.classList.remove('bc-red');
    return true;
  }
}

function cleanInput(inputId) {
  const cleanInput = document.getElementById(inputId);

  cleanInput.value='';
}

function hidePwdRuleToolTooltip(inputId) {
  const input = document.getElementById(inputId);

  if(!input) return;
  
  if (input.id == 'passwordNew') {
    const pwdRuleTooltip = document.getElementById('pwdRuleTooltip');
    pwdRuleTooltip.classList.remove('show-pwd-rule-tooltip');
  }
}

// 初次登入輸入元素
const passwordNew = document.getElementById('passwordNew');
const passwordConfirm = document.getElementById('passwordConfirm');
// 添加事件監聽器
if (passwordNew && passwordConfirm){
  passwordNew.addEventListener('input', canFirstLoginSubmitAllow);
  passwordConfirm.addEventListener('input', canFirstLoginSubmitAllow);
}
// 是否開放submit按鈕可以按
function canFirstLoginSubmitAllow() {
  const passwordNewSubmit = document.getElementById('passwordNewSubmit');
  if (passwordNew.value && passwordConfirm.value) {
    passwordNewSubmit.disabled = false;
  } else {
    passwordNewSubmit.disabled = true;
  }
}

// 忘記密碼輸入元素
const forgetPwdInput = document.getElementById('forgetPwdInput');
// 添加事件監聽器
if (forgetPwdInput) {
  forgetPwdInput.addEventListener('input', canForgetPwdSubmitAllow);
}
// 是否開放submit按鈕可以按
function canForgetPwdSubmitAllow() {
  const forgetPwdSubmit = document.getElementById('forgetPwdSubmit');
  if (forgetPwdInput.value) {
    forgetPwdSubmit.disabled = false;
  } else {
    forgetPwdSubmit.disabled = true;
  }
}

// 登入輸入元素
const usernameInput = document.getElementById('usernameInput');
const passwordInput = document.getElementById('password');
// 添加事件監聽器
if (usernameInput) {
  usernameInput.addEventListener('input', canLoginSubmitAllow);
}
if (passwordInput) {
  passwordInput.addEventListener('input', canLoginSubmitAllow);
}
// 是否開放登入按鈕可以按
function canLoginSubmitAllow() {
  const loginButton = document.getElementById('loginButton');
  if (usernameInput.value && passwordInput.value) {
    loginButton.disabled = false;
  } else {
    loginButton.disabled = true;
  }
}

function termsPageStyleChange(backgroundPath) {
  const container = document.getElementById('container');
  const centerContainer = document.getElementById('centerContainer');
  const centerContainerInner = document.getElementById('centerContainerInner');
  // const localesRegistration = document.getElementById('localesRegistration');
  const subtitle = document.getElementById('subtitle');
  const cardMain = document.getElementById('cardMain');

  container.style.backgroundImage = backgroundPath;

  centerContainer.classList.remove('shadow-lg', 'bg-white');
  centerContainer.classList.add('terms-center-container');

  centerContainerInner.classList.remove('center-container-inner');
  centerContainerInner.classList.add('center-container-inner-terms');

  // localesRegistration.style.display = 'none';

  subtitle.classList.add('fs-40');
  subtitle.classList.remove('fs-24');
  subtitle.classList.remove('justify-center');

  cardMain.style='';
  cardMain.classList.remove('space-y-4');
}
