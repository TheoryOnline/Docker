Import-Module -DisableNameChecking -Force $PSScriptRoot/../jenkins-support.psm1
Import-Module -DisableNameChecking -Force $PSScriptRoot/test_helpers.psm1
$SUT_IMAGE=Get-SutImage
$SUT_CONTAINER=Get-SutImage

Describe 'build image' {
  BeforeEach {
    Push-Location -StackName 'jenkins' -Path "$PSScriptRoot/.."    
  }

  It 'builds image' {
    $exitCode, $stdout, $stderr = Build-Docker -t $SUT_IMAGE . 
    $exitCode | Should -Be 0
  }

  AfterEach {
    Pop-Location -StackName 'jenkins'
  }
}

Describe 'cleanup container' {
  It 'cleanup' {
    Cleanup $SUT_CONTAINER | Out-Null
  }
}

Describe 'test multiple JENKINS_OPTS' {
  It '"--help --version" should return the version, not the help' {
    $dockerfile = Get-EnvOrDefault 'DOCKERFILE' 'Dockerfile-windows'
    $version=cat $PSScriptRoot/../$dockerFile | Select-String -Pattern 'ENV JENKINS_VERSION.*' | %{$_ -replace '.*:-(.*)}','$1'} | Select-Object -First 1
    # need the last line of output
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run --rm -e JENKINS_OPTS=`"--help --version`" --name $SUT_CONTAINER -P $SUT_IMAGE"
    $exitCode | Should -Be 0
    $stdout -split '`n' | %{$_.Trim()} | Select-Object -Last 1 | Should -Be $version
  }
}

Describe 'test jenkins arguments' {
  It 'running --help --version should return the version, not the help' {
    $dockerfile = Get-EnvOrDefault 'DOCKERFILE' 'Dockerfile-windows'
    $version=cat $PSScriptRoot/../$dockerFile | Select-String -Pattern 'ENV JENKINS_VERSION.*' | %{$_ -replace '.*:-(.*)}','$1'} | Select-Object -First 1
    # need the last line of output
    $exitCode, $stdout, $stderr = Run-Program 'docker.exe' "run --rm --name $SUT_CONTAINER -P $SUT_IMAGE --help --version"
    $exitCode | Should -Be 0
    $stdout -split '`n' | %{$_.Trim()} | Select-Object -Last 1 | Should -Be $version
  }
}

Describe 'create test container' {
  It 'start container' {
    $cmd = @"
docker --% run -d -e JAVA_OPTS="-Duser.timezone=Europe/Madrid -Dhudson.model.DirectoryBrowserSupport.CSP=\"default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';\"" --name $SUT_CONTAINER -P $SUT_IMAGE
"@
    Invoke-Expression $cmd
    $lastExitCode | Should -Be 0
  }
}

Describe 'test container is running' {
  It 'is running' {
    # give time to eventually fail to initialize
    Sleep -Seconds 5
    Retry-Command -RetryCount 3 -Delay 1 -ScriptBlock { docker inspect -f "{{.State.Running}}" $SUT_CONTAINER ; if($lastExitCode -ne 0) { throw('Docker inspect failed') } } -Verbose | Should -BeTrue
  }
}

Describe 'Jenkins is initialized' {
  It 'is initialized' {
    # it takes a while for jenkins to be up enough
    Retry-Command -RetryCount 30 -Delay 5 -ScriptBlock { Test-Url $SUT_CONTAINER "/api/json" } -Verbose | Should -BeTrue
  }
}

Describe 'JAVA_OPTS are set' {
  It 'CSP value' {
    $content = (Get-JenkinsWebpage $SUT_CONTAINER "/systemInfo").Replace("</tr>","</tr>`n").Replace("<wbr>", "").Split("`n") | Select-String -Pattern '<td class="pane">hudson.model.DirectoryBrowserSupport.CSP</td>' 
    $content | Should -Match ([regex]::Escape("default-src &#039;self&#039;; script-src &#039;self&#039; &#039;unsafe-inline&#039; &#039;unsafe-eval&#039;; style-src &#039;self&#039; &#039;unsafe-inline&#039;;"))
  }

  It 'Timezone set' {
    $content = (Get-JenkinsWebpage $SUT_CONTAINER "/systemInfo").Replace("</tr>","</tr>`n").Replace("<wbr>", "").Split("`n") | Select-String -Pattern '<td class="pane">user.timezone</td>' 
    $content | Should -Match ([regex]::Escape("Europe/Madrid"))
  }
}

Describe 'cleanup container' {
  It 'cleanup' {
    Cleanup $SUT_CONTAINER | Out-Null
  }
}
