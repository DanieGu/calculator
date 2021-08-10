using namespace System;

[CmdletBinding()]
param(
	[parameter(Mandatory=$true,HelpMessage="Amount of force exerted by the gas lift.")]
    [Alias("lf")]
	[float]$LiftForce,

    [parameter(Mandatory=$true,HelpMessage="Length of gas lift when compressed.")]
    [Alias("lc")]
	[float]$LiftCompressed,

    [parameter(Mandatory=$true,HelpMessage="Length of gas lift when extended.")]
    [Alias("le")]
	[float]$LiftExtended,

    [parameter(Mandatory=$true,HelpMessage="Distance from hinge of lid where gas lift is mounted.")]
    [Alias("mpl")]
	[float]$MountPointLid,

    [parameter(Mandatory=$true,HelpMessage="Distance vertically from lid where other end of gas lift is mounted.")]
    [Alias("mpw")]
	[float]$MountPointWall,

    [parameter(Mandatory=$true,HelpMessage="Weight of lid")]
    [Alias("lw")]
	[float]$LidWeight,

    [parameter(Mandatory=$true,HelpMessage="Length of lid")]
    [Alias("ll")]
	[float]$LidLength,

    [parameter(HelpMessage="Length of gas lift left unused")]
    [Alias("lu")]
	[float]$LiftUnused = 0,

    [parameter(HelpMessage="Mount the lift inverse where the lift collapses towards the hinge.")]
    [Alias("mi")]
	[switch]$MountInverse
)

function DtoR ([Double] $degrees)
{
    return (([Math]::PI / 180d) * $degrees);
}

function RtoD([Double] $radians)
{
    return (57.2958d * $radians);          
}

$liftCompressed = $LiftCompressed + $LiftUnused;
$liftExpanded = $LiftExtended;
$x = $MountPointLid;
$y = $MountPointWall;
$w = $LidWeight;
$l = $LidLength;

Write-Host "Lift force $liftForce";
Write-Host "Lift compressed $liftCompressed, extended $liftExpanded";

#d is the length along the horizontal to mount the force 
#this is calculated to allow the life compressed to mount  
[Double] $d = 0;       
if($MountInverse)
{
    $d = $x + [Math]::Sqrt([Math]::Pow($liftCompressed, 2) - [Math]::Pow($y, 2));
}
else
{
    $d = $x - [Math]::Sqrt([Math]::Pow($liftCompressed, 2) - [Math]::Pow($y, 2));
    if($d -lt 0)
    {
        Write-Host "Invalid mount point too close to hinge.";
        return;
    }
}
Write-Host ("Mounted {0} from hinge on lid and {1:#.##},{2} on wall." -f $x,$d,$y);

Write-Host "Lid weighs $w and is $l long.";

#dh is the hypotenuse of the triangle formed with y below d 
$dh = [Math]::Sqrt([Math]::Pow($d, 2) + [Math]::Pow($y,2));

$done = $false
[Double]$angle = DtoR 0; #in radians  
while(-not $done)
{
    $angleDegrees = RtoD $angle;

    if($angleDegrees -gt 90)
    {
        $angleDegrees = 90
        $angle = DtoR $angleDegrees
        
        Write-Host "90 degrees reached"
        $done = $true
    }

    #compute the angle below the horizontal where the lift is mounted
    #we will add this to the angle the lid is raised to get an angle for the corner of the triangle formed with x and dh
    #this is the same with both the inverse mount and regular
    $dAngle = [Math]::Atan($y / $d);

    #total angle
    [Double]$tAngle = $dAngle + $angle;

    #find the lift extension, the lift extension is the third side of the triangle formed with x and dh
    #this is the SAS triangle because we know the angle in between the sides 
    #https:#www.mathsisfun.com/algebra/trig-solving-sas-triangles.html
    $liftExtension = [Math]::Sqrt([Math]::Pow($x, 2) + [Math]::Pow($dh, 2) -(2 * $x * $dh * [Math]::Cos($tAngle)));
    if($liftExtension -gt $liftExpanded)
    {
        $liftExtension = $liftExpanded
        #recalculate the angle,  this would now be and sss triangle because we know all 3 sides
        $tAngle = [Math]::Acos(([Math]::Pow($x, 2) + [Math]::Pow($dh, 2) - [Math]::Pow($liftExtension, 2)) / (2 * $x * $dh))
        $angle = $tAngle - $dAngle
        $angleDegrees = RtoD $angle

        Write-Host "Max lift extension reached"
        $done = $true
    }

    #find the small angle
    [Double] $fAngle = 0;
    if($MountInverse)
    {
        $fAngle = (DtoR 180) - ((DtoR 180) - [Math]::Asin(([Math]::Sin($tAngle) * $x) / $liftExtension) - $tAngle);
    }
    else 
    {
        $fAngle = [Math]::Asin(([Math]::Sin($tAngle) * $dh) / $liftExtension);
    }

    $fApplied = $liftForce * [Math]::Sin($fAngle);

    #weight of the lid at the xpoint for the angle
    $xWeight = [Math]::Cos($angle) * (($w * $l) / (2 * $x));

    #net force being applied 
    $xNetWeight = $xWeight - $fApplied;

    #weight at the end of the lid after lift force calculated
    $lWeight = (($xNetWeight * 2 * $x) / $l) / 2;


    #calculate the force applied by the lift at the xpoint
    Write-Host ("angle {0:#.#}, extension {1:#.#}, force applied {2:#.#} at {3:#.#}$([char]0x00B0), need {4:#.#}" -f $angleDegrees, $liftExtension,$fApplied,(RtoD $fAngle),$lWeight);

    $angle = DtoR($angleDegrees + 1);
}