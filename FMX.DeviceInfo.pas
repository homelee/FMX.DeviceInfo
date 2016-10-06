unit FMX.DeviceInfo;

{
  Device Info
  author: ZuBy

  ANDROID permissions:
  ..access_network_state
  ..acces_wifi_state
}

interface

uses
  System.SysUtils, System.Types, System.Devices, FMX.Platform
{$IFDEF MSWINDOWS}, Winapi.Windows {$ENDIF}
{$IFDEF ANDROID}, AndroidApi.JNI.GraphicsContentViewText, AndroidApi.JNI.OS, AndroidApi.Helpers, AndroidApi.JNI.Net,
  AndroidApi.JNI.JavaTypes, AndroidApi.JNIBridge, AndroidApi.JNI.Provider, AndroidApi.JNI.Telephony,
  FMX.PhoneDialer, FMX.PhoneDialer.Android {$ENDIF}
{$IFDEF MACOS}, Macapi.ObjectiveC, Posix.Wchar, Macapi.CoreFoundation, Macapi.Dispatch, Posix.SysSocket
{$IFDEF IOS}, iOSApi.CocoaTypes, iOSApi.Foundation, iOSApi.UIKit, FMX.Helpers.iOS{$ENDIF}
{$ENDIF MACOS};

type
  TmyConnectionType = (ctNone, ctUnknown, ctWIFI, ctMobile, ctEthernet);
  TmyNetworkType = (ntNone, ntUnknown, nt2G, nt3G, nt4G);

const
  TmyConnectionTypeString: array [TmyConnectionType] of string = ('None', 'Unknown', 'Wi-Fi', 'Mobile Data',
    'Ethernet');
  TmyNetworkTypeString: array [TmyNetworkType] of string = ('None', 'Unknown', '2G', '3G', '4G');

type
  TmyDeviceInfo = record
    diPlatform: string;
    diPlatformT: TOSVersion.TPlatform;
    diArchitecture: string;
    diArchitecture2: string;
    diArchitectureT: TOSVersion.TArchitecture;
    diMacAddress: string;
    diIPAddress: string;
    diPlatformVer: string;
    diDevice: string;
    diLang: string;
    diScreenPhis: string;
    diScreenLogic: string;
    diScreenWidth: Single;
    diScreenHeight: Single;
    diScale: Single;
    diMobileOperator: string;
    diTimeZone: integer;
    diIsIntel: Boolean;
  end;

var
  DeviceInfo: TmyDeviceInfo;

  /// <summary> ��������� ���������� � ������� </summary>
procedure DeviceInfoByPlatform;
/// <summary> �������� ���� �� �������� [ANDROID, WINDOWS] </summary>
function IsNetConnected: Boolean;

/// <summary> ��� ����������� � ��������� [ANDROID, WINDOWS] </summary>
function IsNetConnectionType: TmyConnectionType;
/// <summary> ��� ��������� ���� [ANDROID] </summary>
function IsNetworkType: TmyNetworkType;

/// <summary> ������� GPS? [ANDROID] </summary>
function IsGPSActive(HIGH_ACCURACY: Boolean = False): Boolean;

/// <summary> ��� �������? [ALL PLATFORMS]</summary>
function IsDeviceType: TDeviceInfo.TDeviceClass;

/// <summary> �������� �� �������� ��� ��������? [ALL PLATFORMS]</summary>
function IsTablet: Boolean;

/// <summary> ���������� ����������? [ALL PLATFORMS] </summary>
function IsPortraitOrientation: Boolean;

/// <summary> ��� ������? [ANDROID/IOS] </summary>
function IsLargePhone: Boolean;

{$IFDEF MacOS }

const
  libc = '/usr/lib/libc.dylib';
function sysctlbyname(Name: MarshaledAString; oldp: pointer; oldlen: Psize_t; newp: pointer; newlen: size_t): integer;
  cdecl; external libc name _PU + 'sysctlbyname';
{$ENDIF }
//
{$IFDEF MSWINDOWS}
function InternetGetConnectedState(lpdwFlags: LPDWORD; dwReserved: DWORD): BOOL; stdcall;
  external 'wininet.dll' name 'InternetGetConnectedState';
{$ENDIF}

implementation

uses
  System.DateUtils, System.Math, FMX.Dialogs, FMX.Styles, FMX.Controls, FMX.BehaviorManager, FMX.Forms, FMX.Types
{$IFDEF MSWINDOWS}, System.Variants, Winapi.ActiveX, System.Win.ComObj{$ENDIF};

// *** FMX.MultiView ***
function IsMobilePreview(Sender: TControl): Boolean;
var
  StyleDescriptor: TStyleDescription;
begin
  StyleDescriptor := TStyleManager.GetStyleDescriptionForControl(Sender);
  if StyleDescriptor <> nil then
    Result := StyleDescriptor.MobilePlatform
  else
    Result := False;
end;

function DefineDeviceClassByFormSize: TDeviceInfo.TDeviceClass;
const
  MaxPhoneWidth = 640;
begin
  if Screen.ActiveForm.Width <= MaxPhoneWidth then
    Result := TDeviceInfo.TDeviceClass.Phone
  else
    Result := TDeviceInfo.TDeviceClass.Tablet;
end;

function IsDeviceType: TDeviceInfo.TDeviceClass;
var
  DeviceService: IDeviceBehavior;
  Context: TFMXObject;
begin
  Context := Screen.ActiveForm;
  if TBehaviorServices.Current.SupportsBehaviorService(IDeviceBehavior, DeviceService, Context) then
    Result := DeviceService.GetDeviceClass(Context)
  else
    Result := DefineDeviceClassByFormSize;
end;

function IsTablet: Boolean;
begin
  Result := IsDeviceType = TDeviceInfo.TDeviceClass.Tablet;
{$IFDEF IOS}
  Result := IsPad;
{$ENDIF}
end;

function IsPortraitOrientation: Boolean;
var
  FScreenService: IFMXScreenService;
begin
  Result := true;
  if TPlatformServices.Current.SupportsPlatformService(IFMXScreenService, FScreenService) then
    Result := (FScreenService.GetScreenOrientation = TScreenOrientation.Portrait) or
      (FScreenService.GetScreenOrientation = TScreenOrientation.InvertedPortrait);
end;

function IsLargePhone: Boolean;
{$IF defined(ANDROID) or defined(IOS)}
const
  MinLogicaSizeForLargePhone = 736;
var
  ThisDevice: TDeviceInfo;
{$ENDIF}
begin
  Result := False;
{$IF defined(ANDROID) or defined(IOS)}
  ThisDevice := TDeviceInfo.ThisDevice;
  if ThisDevice <> nil then
    Result := Max(ThisDevice.MinLogicalScreenSize.Width, ThisDevice.MinLogicalScreenSize.Height) >=
      MinLogicaSizeForLargePhone
  else
    Result := true;
{$ENDIF}
end;
// *** FMX.MultiView ***

{$IFDEF MACOS}

function GetSysInfoByName(typeSpecifier: string): string;
var
  Size: integer;
  AResult: TArray<Byte>;
begin
  sysctlbyname(MarshaledAString(TMarshal.AsAnsi(typeSpecifier)), nil, @Size, nil, 0);
  SetLength(AResult, Size);
  sysctlbyname(MarshaledAString(TMarshal.AsAnsi(typeSpecifier)), MarshaledAString(AResult), @Size, nil, 0);
  Result := TEncoding.UTF8.GetString(AResult);
end;
{$ENDIF}
//
{$IFDEF ANDROID}

function getMobileType(jType: integer): TmyConnectionType;
begin
  Result := ctUnknown; // Unknown connection type
  if jType = TJConnectivityManager.JavaClass.TYPE_ETHERNET then
    Result := ctEthernet
  else if jType = TJConnectivityManager.JavaClass.TYPE_WIFI then
    Result := ctWIFI
  else
  begin
    if (jType = TJConnectivityManager.JavaClass.TYPE_MOBILE) or
      (jType = TJConnectivityManager.JavaClass.TYPE_MOBILE_DUN) or
      (jType = TJConnectivityManager.JavaClass.TYPE_MOBILE_HIPRI) or
      (jType = TJConnectivityManager.JavaClass.TYPE_MOBILE_MMS) or
      (jType = TJConnectivityManager.JavaClass.TYPE_MOBILE_SUPL) or (jType = TJConnectivityManager.JavaClass.TYPE_WIMAX)
    then
      Result := ctMobile;
  end;
end;

function getMobileSubType(jType: integer): TmyNetworkType;
begin
  Result := ntUnknown;
  if (jType = TJTelephonyManager.JavaClass.NETWORK_TYPE_GPRS) or
    (jType = TJTelephonyManager.JavaClass.NETWORK_TYPE_EDGE) or (jType = TJTelephonyManager.JavaClass.NETWORK_TYPE_CDMA)
    or (jType = TJTelephonyManager.JavaClass.NETWORK_TYPE_1xRTT) or
    (jType = TJTelephonyManager.JavaClass.NETWORK_TYPE_IDEN) then
    Result := nt2G
  else if (jType = TJTelephonyManager.JavaClass.NETWORK_TYPE_UMTS) or
    (jType = TJTelephonyManager.JavaClass.NETWORK_TYPE_EVDO_0) or
    (jType = TJTelephonyManager.JavaClass.NETWORK_TYPE_EVDO_A) or
    (jType = TJTelephonyManager.JavaClass.NETWORK_TYPE_HSDPA) or
    (jType = TJTelephonyManager.JavaClass.NETWORK_TYPE_HSUPA) or
    (jType = TJTelephonyManager.JavaClass.NETWORK_TYPE_HSPA) or
    (jType = TJTelephonyManager.JavaClass.NETWORK_TYPE_EVDO_B) or
    (jType = TJTelephonyManager.JavaClass.NETWORK_TYPE_EHRPD) or
    (jType = TJTelephonyManager.JavaClass.NETWORK_TYPE_HSPAP) then
    Result := nt3G
  else if (jType = TJTelephonyManager.JavaClass.NETWORK_TYPE_LTE) then
    Result := nt4G;
end;

function GetWifiManager: JWifiManager;
var
  WifiManagerObj: JObject;
begin
  WifiManagerObj := TAndroidHelper.Context.getSystemService(TJContext.JavaClass.WIFI_SERVICE);
  if not Assigned(WifiManagerObj) then
    raise Exception.Create('Could not locate Wifi Service');
  Result := TJWifiManager.Wrap((WifiManagerObj as ILocalObject).GetObjectID);
  if not Assigned(Result) then
    raise Exception.Create('Could not access Wifi Manager');
end;

function GetTelephonyManager: JTelephonyManager;
var
  TelephoneServiceNative: JObject;
begin
  TelephoneServiceNative := TAndroidHelper.Context.getSystemService(TJContext.JavaClass.TELEPHONY_SERVICE);
  if not Assigned(TelephoneServiceNative) then
    raise Exception.Create('Could not locate Telephony Service');
  Result := TJTelephonyManager.Wrap((TelephoneServiceNative as ILocalObject).GetObjectID);
  if not Assigned(Result) then
    raise Exception.Create('Could not access Telephony Manager');
end;

function GetConnectivityManager: JConnectivityManager;
var
  ConnectivityServiceNative: JObject;
begin
  ConnectivityServiceNative := TAndroidHelper.Context.getSystemService(TJContext.JavaClass.CONNECTIVITY_SERVICE);
  if not Assigned(ConnectivityServiceNative) then
    raise Exception.Create('Could not locate Connectivity Service');
  Result := TJConnectivityManager.Wrap((ConnectivityServiceNative as ILocalObject).GetObjectID);
  if not Assigned(Result) then
    raise Exception.Create('Could not access Connectivity Manager');
end;

procedure GetAddress(out aMac, aWifiIP: string);
var
  WifiManager: JWifiManager;
  WifiInfo: JWifiInfo;
  ip: integer;
begin
  WifiManager := GetWifiManager;
  if Assigned(WifiManager) then
  begin
    WifiInfo := WifiManager.getConnectionInfo;
    aMac := JStringToString(WifiInfo.getMacAddress);
    ip := WifiInfo.GetIPAddress;
    aWifiIP := Format('%d.%d.%d.%d', [ip and $FF, ip shr 8 and $FF, ip shr 16 and $FF, ip shr 24 and $FF]);
  end;
end;

function GetCodename(VerString: string): string;
begin
  if Pos('4.4', VerString) = 1 then
    Result := 'Kit Kat'
  else if Pos('4.0', VerString) > 0 then
    Result := 'ICS'
  else if Pos('4.', VerString) > 0 then
    Result := 'JB'
  else if (Pos('5.', VerString) > 0) then
    Result := 'Lollipop'
  else if Pos('6.', VerString) > 0 then
    Result := 'Marshmallow'
  else
    Result := 'Unknown';
end;
{$ENDIF}

function IsGPSActive(HIGH_ACCURACY: Boolean = False): Boolean;
var
  Provider: string;
  LocationMode: integer;
begin
  Result := true; // for all platforms
{$IFDEF ANDROID}
  if TOSVersion.Check(4, 4) then
  begin
    LocationMode := TJSettings_Secure.JavaClass.getInt(TAndroidHelper.Context.getContentResolver,
      TJSettings_Secure.JavaClass.LOCATION_MODE);
    if HIGH_ACCURACY then
      Result := LocationMode <> TJSettings_Secure.JavaClass.LOCATION_MODE_HIGH_ACCURACY
    else
      Result := LocationMode <> TJSettings_Secure.JavaClass.LOCATION_MODE_OFF;
  end
  else
  begin
    Provider := JStringToString(TJSettings_Secure.JavaClass.GetString(TAndroidHelper.Context.getContentResolver,
      TJSettings_system.JavaClass.LOCATION_PROVIDERS_ALLOWED));
    if HIGH_ACCURACY then
      Result := Pos('gps', Provider) > 0
    else
      Result := (Pos('network', Provider) > 0) or (Pos('gps', Provider) > 0);
  end;
{$ENDIF}
end;

function IsNetConnected: Boolean;
{$IFDEF MSWINDOWS}
const
  INTERNET_CONNECTION_MODEM      = 1;
  INTERNET_CONNECTION_LAN        = 2;
  INTERNET_CONNECTION_PROXY      = 4;
  INTERNET_CONNECTION_MODEM_BUSY = 8;
var
  dwConnectionTypes: DWORD;
{$ENDIF}
begin
  Result := False;
{$IF defined(ANDROID)}
  Result := IsNetConnectionType <> ctNone;
{$ELSEIF defined(MSWINDOWS)}
  dwConnectionTypes := INTERNET_CONNECTION_MODEM or INTERNET_CONNECTION_LAN or INTERNET_CONNECTION_PROXY;
  Result := InternetGetConnectedState(@dwConnectionTypes, 0);
{$ENDIF}
end;

function IsNetworkType: TmyNetworkType;
{$IFDEF ANDROID}
var
  TelephoneManager: JTelephonyManager;
  cellList: JObject;
  infoGSM: JCellInfoGsm;
  gsmStrength: JCellSignalStrength;
{$ENDIF}
begin
  Result := {$IF defined(MSWINDOWS) or defined(MACOS)}ntNone {$ELSE} ntUnknown{$ENDIF};
{$IFDEF ANDROID}
  TelephoneManager := GetTelephonyManager;
  if (Assigned(TelephoneManager)) and (TelephoneManager.getSimState = TJTelephonyManager.JavaClass.SIM_STATE_READY) then
  begin
    Result := getMobileSubType(TelephoneManager.getNetworkType);
  end;
{$ENDIF}
end;

function IsNetConnectionType: TmyConnectionType;
{$IFDEF ANDROID}
var
  ConnectivityManager: JConnectivityManager;
  ActiveNetwork: JNetworkInfo;
{$ENDIF}
begin
  Result := ctNone;
{$IFDEF ANDROID}
  ConnectivityManager := GetConnectivityManager;
  if Assigned(ConnectivityManager) then
  begin
    ActiveNetwork := ConnectivityManager.getActiveNetworkInfo;
    if Assigned(ActiveNetwork) and ActiveNetwork.isConnected then
      Result := getMobileType(ActiveNetwork.getType);
  end;
{$ELSEIF defined(MSWINDOWS)}
  if IsNetConnected then
    Result := ctEthernet;
{$ENDIF}
end;

{$IFDEF MSWINDOWS}

procedure GetAddress(out aMac, aIP: string);
const
  wbemFlagForwardOnly = $00000020;
var
  FSWbemLocator: OLEVariant;
  FWMIService: OLEVariant;
  FWbemObjectSet: OLEVariant;
  FWbemObject: OLEVariant;
  oEnum: IEnumvariant;
  iValue: LongWord;
begin
  FSWbemLocator := CreateOleObject('WbemScripting.SWbemLocator');
  FWMIService := FSWbemLocator.ConnectServer('localhost', 'root\CIMV2', '', '');
  FWbemObjectSet := FWMIService.ExecQuery
    ('SELECT Description,MACAddress,IPAddress FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled=TRUE', 'WQL',
    wbemFlagForwardOnly);

  oEnum := IUnknown(FWbemObjectSet._NewEnum) as IEnumvariant;
  while oEnum.Next(1, FWbemObject, iValue) = 0 do
  begin
    if not VarIsNull(FWbemObject.MACAddress) then
      aMac := VarToStr(FWbemObject.MACAddress);
    if not VarIsNull(FWbemObject.IPAddress) then
      aIP := VarToStr(FWbemObject.IPAddress[0]);

    if not(aMac.IsEmpty and aIP.IsEmpty) then
    begin
      FWbemObject := Unassigned;
      break;
      exit;
    end;
    FWbemObject := Unassigned;
  end;
end;
{$ENDIF}

function FloatS(const aValue: Single): string;
var
  Buf: TFormatSettings;
begin
  Buf := FormatSettings;
  Buf.DecimalSeparator := '.';
  Result := FloatToStr(aValue, Buf);
end;

procedure DeviceInfoByPlatform;
const
  sPlatform: array [TOSVersion.TPlatform] of string = ('Windows', 'MacOS', 'IOS', 'Android', 'WinRT', 'Linux');
  sArchitecture: array [TOSVersion.TArchitecture] of string = ('IntelX86', 'IntelX64', 'ARM32', 'ARM64');
var
  sScale: Single;
  sScreenSize: TPoint;
  ScreenService: IFMXScreenService;
  LocaleService: IFMXLocaleService;
{$IFDEF ANDROID}
  I: integer;
  arrObjAbis: TJavaObjectArray<JString>;
  sAbis: string;
  PhoneService: IFMXPhoneDialerService;
{$ENDIF}
begin
  DeviceInfo.diPlatform := sPlatform[TOSVersion.Platform];
  DeviceInfo.diPlatformT := TOSVersion.Platform;
  DeviceInfo.diArchitecture := sArchitecture[TOSVersion.Architecture];
  DeviceInfo.diArchitectureT := TOSVersion.Architecture;
  DeviceInfo.diMobileOperator := 'unknown';
  DeviceInfo.diIsIntel := DeviceInfo.diArchitecture.Contains('IntelX');

  case TOSVersion.Platform of
    pfMacOS:
      begin
{$IFDEF MACOS}
        DeviceInfo.diDevice := 'MacOS (' + trim(GetSysInfoByName('hw.model')) + ')';
        DeviceInfo.diPlatformVer := GetSysInfoByName('kern.ostype') + ' ' + GetSysInfoByName('kern.osrelease');
{$ENDIF}
      end;
    pfiOS:
      begin
{$IFDEF IOS}
        with TUIDevice.Wrap(TUIDevice.OCClass.currentDevice) do
        begin
          DeviceInfo.diPlatformVer := systemName.UTF8String + ' (' + systemVersion.UTF8String + ')';
          DeviceInfo.diDevice := model.UTF8String;
          DeviceInfo.diMacAddress := identifierForVendor.UUIDString.UTF8String;
          DeviceInfo.diIPAddress := 'unknown';
        end;
        { if TPlatformServices.Current.SupportsPlatformService(IFMXPhoneDialerService, IInterface(PhoneService)) then
          begin
          try
          DeviceInfo.diMobileOperator := PhoneService.GetCarrier.GetCarrierName + ' ' +
          PhoneService.GetCarrier.GetMobileCountryCode
          except
          end;
          end; }
{$ENDIF}
      end;
    pfAndroid:
      begin
{$IFDEF ANDROID}
        if TOSVersion.Major >= 5 then
        begin
          sAbis := '';
          arrObjAbis := TJBuild.JavaClass.SUPPORTED_ABIS;
          for I := 0 to arrObjAbis.Length - 1 do
            sAbis := sAbis + ',' + JStringToString(arrObjAbis.Items[I]);
          sAbis := sAbis.trim([',']);
        end
        else
          sAbis := JStringToString(TJBuild.JavaClass.CPU_ABI) + ',' + JStringToString(TJBuild.JavaClass.CPU_ABI2);

        DeviceInfo.diArchitecture2 := sAbis;
        DeviceInfo.diIsIntel := sAbis.Contains('x86') or JStringToString(TJBuild.JavaClass.FINGERPRINT)
          .Contains('intel');

        DeviceInfo.diPlatformVer := GetCodename(JStringToString(TJBuild_VERSION.JavaClass.release)) + ' ' +
          JStringToString(TJBuild_VERSION.JavaClass.release);
        DeviceInfo.diDevice := JStringToString(TJBuild.JavaClass.MANUFACTURER) + ' ' +
          JStringToString(TJBuild.JavaClass.model);
        GetAddress(DeviceInfo.diMacAddress, DeviceInfo.diIPAddress);

        if TPlatformServices.Current.SupportsPlatformService(IFMXPhoneDialerService, IInterface(PhoneService)) then
        begin
          try
            DeviceInfo.diMobileOperator := PhoneService.GetCarrier.GetCarrierName + ' ' +
              PhoneService.GetCarrier.GetMobileCountryCode
          except
          end;
        end;
{$ENDIF}
      end;
    pfWindows:
      begin
{$IFDEF MSWINDOWS}
        DeviceInfo.diPlatformVer := TOSVersion.Major.ToString + '.' + TOSVersion.Minor.ToString;
        DeviceInfo.diDevice := TOSVersion.Name;
        GetAddress(DeviceInfo.diMacAddress, DeviceInfo.diIPAddress);
{$ENDIF}
      end;
  end;

  if TPlatformServices.Current.SupportsPlatformService(IFMXScreenService, IInterface(ScreenService)) then
  begin
    sScreenSize := ScreenService.GetScreenSize.Round;
    sScale := ScreenService.GetScreenScale;
    DeviceInfo.diScreenLogic := FloatS(sScreenSize.x) + ' x ' + FloatS(sScreenSize.y);
    DeviceInfo.diScreenPhis := FloatS(sScreenSize.x * sScale) + ' x ' + FloatS(sScreenSize.y * sScale);
    DeviceInfo.diScreenWidth := sScreenSize.x;
    DeviceInfo.diScreenHeight := sScreenSize.y;
    DeviceInfo.diScale := sScale;
  end;

  if TPlatformServices.Current.SupportsPlatformService(IFMXLocaleService, IInterface(LocaleService)) then
    DeviceInfo.diLang := LocaleService.GetCurrentLangID;

  with TTimeZone.Create do
  begin
    DeviceInfo.diTimeZone := (((Local.UtcOffset.Hours * 60) + Local.UtcOffset.Minutes) * 60) + Local.UtcOffset.Seconds;
    Free;
  end;
end;

{$IFDEF MSWINDOWS}

initialization

CoInitialize(nil);

finalization

CoUninitialize;
{$ENDIF}

end.
