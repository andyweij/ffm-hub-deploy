<#import "my-header.ftl" as myheader>
<#import "my-footer.ftl" as myfooter>

<#macro kw>
  <div id="container" class="min-h-screen sm:py-16 flex items-center justify-center items-center" style="background-image: linear-gradient(128deg, #bcc5ff, #bed0ff, #e6e4ff, #c9fffb); flex-direction: column; position: relative;">
    <!-- <@myheader.kw> -->
    <!-- </@myheader.kw> -->
    <div id="centerContainer" class="center-container w-fit flex justify-center items-center p-5 relative mx-auto my-auto rounded-xl shadow-lg bg-white">
      <div id="centerContainerInner" class="center-container-inner items-center justify-center flex space-between">
        <div class="space-y-6 w-full">
          <#nested>
        </div>
      </div>
    </div>
    <@myfooter.kw>
    </@myfooter.kw>
  </div>
</#macro>