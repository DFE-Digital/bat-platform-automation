[CmdletBinding()]

Param(

 # [Parameter(Mandatory=$True)]
  
  [string] $appservicename="bat-prod-mcfe-as",
  [int]$timeoutInMinutes = 5
  )


try{

    #Get Web app properties
    $webApp = Get-AzureRmWebApp -Name $appservicename

    #Get Web app Slot properties
    $webAppslots = $webApp | Get-AzureRmWebAppSlot

    $result = @() 

    #Get current date and time for timeout properties
    $startTime = (get-date).ToString()

    #Timer starts now
    write-output "Elapsed:00:00:00"
    $continue = $true

    #Capture all the urls to query
    $uris=$webApp.EnabledHostNames | where {$_ -Like "*.azurewebsites.net*" }
    $uris+=$webAppslots.EnabledHostNames | where {$_ -Like "*.azurewebsites.net*"}
    #exclude scm sites
    $uris = $uris | where {$_ -notlike "*.scm.*"}

    if ($webApp){
        #do while loop terminates only if webapp are up and reachable or when timeout is reached
        While ($continue)
        {

            foreach ($uri in $uris)
            {

                $webrequest = try{ 
 
                    $request = $null 
                    ## Request the URI, and measure how long the response took. 
                    $result1 = Measure-Command { $request = Invoke-WebRequest -Uri "https://$uri" -MaximumRedirection 0 -ErrorAction Ignore } 
                    write-output **Time took to invoke web request: $result1.TotalMilliseconds **
                    $request
                }  
                catch 
                { 
                    $request = $_.Exception.Response 
                    $time = -1 
                }   

                $result += [PSCustomObject] @{ 
                    Time = Get-Date; 
                    Uri = $uri; 
                    StatusCode = [int] $request.StatusCode; 
                    StatusDescription = $request.StatusDescription; 
                    ResponseLength = $request.RawContentLength; 
                    TimeTaken =  $time.TotalMilliseconds;
                    WebRequest = $webrequest 
                }
            }
            $sleeprequired = $false
            foreach ($output in $result){
                $outputstatuscode=$output.StatusCode
                $outputuri=($output.uri).ToString()
                $outputwebrequest= $output.WebRequest.headers.location
                if ($output.StatusCode -eq 200 ){
                        Write-output "$outputuri is up and running. Status code = $outputstatuscode" 
                   }
                   elseif($output.StatusCode -eq 302){
                        Write-Output "$outputuri is up and running. Redirection is in place. Status code = $outputstatuscode "
                        Write-Output "$outputuri is redirected to $outputwebrequest "
                   }
                   else{ 
                        Write-Output "$outputuri site is currently down or unreachable"
                        $sleeprequired = $true
                        # Remove comment to display extra info # write-output $result | fl
                        #reseting previous result
                        $result = @() 
                   }
    
            }

          $currenttime= (get-date).ToString()
          $elapsedTime = new-timespan $startTime $currenttime
          write-output "Elapsed:$($elapsedTime.ToString("hh\:mm\:ss"))"  

          #Handle event
          if($elapsedTime.Minutes -ge $timeoutInMinutes ){$continue = $false}
          elseif($sleeprequired -eq $false)
          { $continue = $false
            }
          else{
                write-output "Sleeping 10s" 
                Start-Sleep 10} 
        }
    }else{

        Write-Output "Web App not found"
    }

}
catch{
    Write-Output "Script terminated with following error:" $error[0].Exception
    
}