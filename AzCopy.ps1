$source = 'D:\AZCopy\Files'
$destinationSASKey = "https://5f5c27d6-5eaf-49cf-ba80-46185e292798.blob.core.windows.net/"
$parameters = '--recursive'

azcopy copy $source $destinationSASKey $parameters
