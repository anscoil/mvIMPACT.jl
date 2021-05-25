module mvIMPACT

export DMR, OBJ

const devicelib = @static (if Sys.islinux(); "libmvDeviceManager.so"
                           elseif Sys.iswindows(); "mvDeviceManager"
                           else nothing end)

function Cstring_format(s::String)
    replace(s, '\0' => "")
end

function check_error(r, f)
    if r != 0
        error("Error in $f (code: $r)")
    end
end

module DMR
import ..mvIMPACT: devicelib, Cstring_format, check_error
export as_str

const aligned_8 = Sys.iswindows()

### Types
struct DeviceInfoType
    dmdit::Int32
end
dmditDeviceInfoStructure = DeviceInfoType(0)
dmditDeviceIsIntUse = DeviceInfoType(1)
dmditDeviceDriver = DeviceInfoType(2)

INFO_STRING_SIZE = 38

struct DeviceInfo
    serial::String
    family::String
    product::String
    firmwareVersion::Int32
    deviceId::Int32
end

struct DeviceSearchMode
    dmdsm::Int32
end
dmdsmSerial = DeviceSearchMode(1)
dmdsmFamily = DeviceSearchMode(2)
dmdsmProduct = DeviceSearchMode(3)
dmdsmUseDevID = DeviceSearchMode(0x8000)

struct ListType
    dmlt::Int32
end
dmltUndefined = ListType(-1)
dmltSetting = ListType(0)
dmltRequest = ListType(1)
dmltRequestCtrl = ListType(2)
dmltInfo = ListType(3)
dmltStatistics = ListType(4)
dmltSystemSettings = ListType(5)
dmltIOSubSystem = ListType(6)
dmltRTCtr = ListType(7)
dmltCameraDescriptions = ListType(8)
dmltDeviceSpecificData = ListType(9)
dmltEventSubSystemSettings = ListType(10)
dmltEventSubSystemResults = ListType(11)
dmltImageMemoryManager = ListType(12)
dmltDeviceDriverLib = ListType(13)

struct TRequestResult
    rr::UInt32
end
rrOK = TRequestResult(0)
rrTimeout = TRequestResult(1)
rrError = TRequestResult(2)
rrRequestAborted = TRequestResult(3)
rrFrameIncomplete = TRequestResult(4)
rrDeviceAccessLost = TRequestResult(5)
rrInconsistentBufferContent = TRequestResult(6)
rrFrameCorrupt = TRequestResult(7)
rrUnprocessibleRequest = TRequestResult(0x80000000)
rrNoBufferAvailable = TRequestResult(rrUnprocessibleRequest.rr | 1)
rrNotEnoughMemory = TRequestResult(rrUnprocessibleRequest.rr | 2)
rrCameraNotSupported = TRequestResult(rrUnprocessibleRequest.rr | 5)
rrDataAcquisitionNotSupported = TRequestResult(rrUnprocessibleRequest.rr | 7)
rr_dict = Dict(rrOK => "OK", rrTimeout => "Timeout",
               rrRequestAborted => "RequestAborted",
               rrFrameIncomplete => "FrameIncomplete",
               rrDeviceAccessLost => "DeviceAccessLost",
               rrInconsistentBufferContent => "InconsistentBufferContent",
               rrFrameCorrupt => "FrameCorrupt",
               rrUnprocessibleRequest => "UnprocessibleRequest",
               rrNoBufferAvailable => "NoBufferAvailable",
               rrNotEnoughMemory => "NotEnoughMemory",
               rrCameraNotSupported => "CameraNotSupported",
               rrDataAcquisitionNotSupported => "DataAcquisitionNotSupported")

struct TRequestState
    rs::UInt32
end
rsIdle = TRequestState(0)
rsWaiting = TRequestState(1)
rsCapturing = TRequestState(2)
rsReady = TRequestState(3)
rsBeingConfigured = TRequestState(4)
rs_dict = Dict(rsIdle => "Idle", rsWaiting => "Waiting",
               rsCapturing => "Capturing", rsReady => "Ready",
               rsBeingConfigured => "BeingConfigured")

struct RequestResult
    result::TRequestResult
    state::TRequestState
    function RequestResult()
        new(TRequestResult(0),TRequestState(0))
    end
end

@static if aligned_8
    struct ChannelData
        iChannelOffset::Int32
        iLinePitch::Int32
        iPixelPitch::Int32
        szChannelDesc::Ptr{UInt8}
    end
else
    struct ChannelData
        iChannelOffset::Int32
        iLinePitch::Int32
        iPixelPitch::Int32
        szChannelDesc::UInt32
        padszChannelDesc::UInt32
    end
end

struct TImageBufferPixelFormat
    ibfp::Int32
end

const IBFP_dict = Dict(0 => "Raw", 1 => "Mono8", 2 => "Mono16",
                       3 => "RGBx888Packed", 4 => "YUV422Packed",
                       5 => "RGBx888Planar", 6 => "Mono10", 7 => "Mono12",
                       8 => "Mono14", 9 => "RGB888Packed", 10 => "YUV444Planar",
                       11 => "Mono32", 12 => "YUV422Planar", 13 => "RGB101010Packed",
                       14 => "RGB121212Packed", 15 => "RGB141414Packed",
                       16 => "RGB161616Packed", 17 => "YUV422_UYVYPacked",
                       18 => "Mono12Packed_V2", 20 => "YUV422_10Packed",
                       21 => "YUV422_UYVY_10Packed", 22 => "BGR888Packed",
                       23 => "BGR101010Packed_V2", 24 => "YUV444_UYVPacked",
                       25 => "YUV444_UYV_10Packed", 26 => "YUV444Packed",
                       27 => "YUV444_10Packed", 28 => "Mono12Packed_V1",
                       29 => "YUV411_UYYVYY_Packed", 30 => "RGB888Planar", -1 => "Auto")

@static if aligned_8
    struct ImageBuffer
        iBytesPerPixel::Int32
        iHeight::Int32
        iWidth::Int32
        pixelFormat::TImageBufferPixelFormat
        iSize::Int32
        vpData::Ptr{Nothing}
        iChannelCount::Int32
        pChannels::Ptr{ChannelData}
    end
else
    struct ImageBuffer
        iBytesPerPixel::Int32
        iHeight::Int32
        iWidth::Int32
        pixelFormat::TImageBufferPixelFormat
        iSize::Int32
        vpData::UInt32
        padvpData::UInt32
        iChannelCount::Int32
        pChannels::UInt32
        padpChannels::UInt32
    end
end

function get_ImageBufferData(p::Ref{Ptr{ImageBuffer}})
    img_buf = unsafe_load(p[])
    ptr = if aligned_8
        img_buf.vpData
    else
        convert(Ptr{Nothing}, UInt(img_buf.padvpData) << 32 | img_buf.vpData)
    end
    T = if img_buf.iBytesPerPixel > 1; UInt16 else UInt8 end
    width = img_buf.iWidth
    height = img_buf.iHeight
    unsafe_wrap(Array, Ptr{T}(ptr), (width,height))
end

function as_str(r::TRequestResult)
    rr_dict[r]
end

function as_str(r::TRequestState)
    rs_dict[r]
end

function as_str(r::RequestResult)
    (as_str(r.result), as_str(r.state))
end

### Functions
function Init()
    hDMR = Ref(Int32(0))
    r = ccall((:DMR_Init, devicelib), Int32, (Ref{Int32},), hDMR)
    check_error(r, "Init")
    hDMR[]
end

function Close()
    r = ccall((:DMR_Close, devicelib), Int32, ())
    check_error(r, "Close")
end

function getDeviceCount()
    pDevCnt = Ref(UInt32(0))
    r = ccall((:DMR_GetDeviceCount, devicelib), Int32, (Ref{UInt32},), pDevCnt)
    check_error(r, "getDeviceCount")
    pDevCnt[]
end

function GetDevice(searchMode::DeviceSearchMode, searchString::String, devNr::Integer)
    pHDev = Ref(Int32(0))
    r = ccall((:DMR_GetDevice, devicelib), Int32, (Ref{Int32},Int32,Cstring,UInt32,UInt8),
              pHDev, searchMode.dmdsm, searchString, UInt32(devNr), '*')
    check_error(r, "GetDevice")
    pHDev[]
end

function GetDeviceNr(devNr)
    GetDevice(dmdsmSerial, "*", devNr)
end

function UInt32_of_UInt8(b1::UInt8, b2::UInt8, b3::UInt8, b4::UInt8; little_endian::Bool=true)
    if little_endian
        UInt32(b4) << 24 | UInt32(b3) << 16 | UInt32(b2) << 8 | UInt32(b1)
    else
        UInt32(b1) << 24 | UInt32(b2) << 16 | UInt32(b3) << 8 | UInt32(b4)
    end
end

function GetDeviceInfoEx(hDev, infoType::DeviceInfoType)
    pInfoSize = Ref{UInt32}(sizeof(Int32))
    pInfo = if infoType == dmditDeviceInfoStructure;
        Ptr{Nothing}() else Ref{Int32}(0) end
    r = ccall((:DMR_GetDeviceInfoEx, devicelib), Int32,
              (Int32,Int32,Ptr{Nothing},Ptr{UInt32}),
              hDev, infoType.dmdit, pInfo, pInfoSize)
    check_error(r, "GetDeviceInfoEx")
    if infoType == dmditDeviceInfoStructure
        buf = zeros(UInt8, pInfoSize[])
        ccall((:DMR_GetDeviceInfoEx, devicelib), Int32,
              (Int32,Int32,Ptr{Nothing},Ptr{UInt32}),
              hDev, infoType.dmdit, buf, pInfoSize)
        firmwareVersion = UInt32_of_UInt8(buf[(3*INFO_STRING_SIZE+1:
                                               3*INFO_STRING_SIZE+4)]...)
        deviceId = UInt32_of_UInt8(buf[(3*INFO_STRING_SIZE+5:
                                               3*INFO_STRING_SIZE+8)]...)
        DeviceInfo(Cstring_format(String(buf[1:INFO_STRING_SIZE])),
                   Cstring_format(String(buf[INFO_STRING_SIZE+1:2*INFO_STRING_SIZE])),
                   Cstring_format(String(buf[2*INFO_STRING_SIZE+1:3*INFO_STRING_SIZE])),
                   firmwareVersion, deviceId)
    else
        pInfo[]
    end
end

function OpenDevice(hDev)
    pHDrv = Ref(Int32(0))
    r = ccall((:DMR_OpenDevice, devicelib), Int32, (Int32,Ref{Int32}), hDev, pHDrv)
    check_error(r, "OpenDevice")
    pHDrv[]
end

function CloseDevice(hDrv, hDev)
    r = ccall((:DMR_CloseDevice, devicelib), Int32, (Int32,Int32), hDrv, hDev)
    check_error(r, "CloseDevice")
end

function ImageRequestSingle(hDrv, requestCtrl, pRequestUsed)
    ccall((:DMR_ImageRequestSingle, devicelib), Int32, (Int32, UInt32, Ref{Int32}),
  	  hDrv, requestCtrl, pRequestUsed)
end

function ImageRequestWaitFor(hDrv, timeout, queueNr, pRequestNr)
    ccall((:DMR_ImageRequestWaitFor, devicelib), Int32,
          (UInt32, UInt32, UInt32, Ref{Int32}),
  	  hDrv, UInt32(timeout), UInt32(queueNr), pRequestNr)
end

function GetImageRequestResultEx(hDrv, requestNr,
                                 pResult::Union{AbstractVector{RequestResult},
                                                Ref{RequestResult}})
    ccall((:DMR_GetImageRequestResultEx, devicelib), Int32,
          (UInt32, Int32, Ref{RequestResult}, Int32, Int32, Int32),
          hDrv, requestNr, pResult, sizeof(RequestResult)*length(pResult), 0, 0)
end

function ImageRequestUnlock(hDrv, requestNr)
    ccall((:DMR_ImageRequestUnlock, devicelib), Int32,
          (UInt32, Int32), hDrv, requestNr)
end

function GetImageRequestBuffer(hDrv, requestNr, ppBuffer)
    ccall((:DMR_GetImageRequestBuffer,devicelib), Int32,
          (UInt32, Int32, Ptr{Ptr{ImageBuffer}}), hDrv, requestNr, ppBuffer)
end

function ReleaseImageRequestBufferDesc(ppBuffer)
    ccall((:DMR_ReleaseImageRequestBufferDesc,devicelib), Int32,
          (Ptr{Ptr{ImageBuffer}},), ppBuffer)
end

function GetImage(hDrv)
    if (error_request = DMR.ImageRequestSingle(hDrv, 0, 0)) != 0
        error("Failed ImageRequestSingle on $hDrv (code: $error_request)")
    end
    pRequestNr = Ref(Int32(0))
    if (error_waitfor = DMR.ImageRequestWaitFor(hDrv, 1000, 0, pRequestNr)) != 0
        error("Failed ImageRequestWaitFor on $hDrv (code: $error_waitfor)")
    end
    requestNr = pRequestNr[]
    pResult = Ref(DMR.RequestResult())
    if (error_result = DMR.GetImageRequestResultEx(hDrv, requestNr, pResult)) != 0
        error("Failed ImageRequestWaitFor on $hDrv for request $requestNr",
              "(code: $error_result)")
    else
        if (pResult[].result != rrOK && pResult[].state != rsReady)
            error("Image request: ", DMR.as_str(pResult[]))
        end
    end
    ppBuffer = Ref(Ptr{ImageBuffer}())
    result = GetImageRequestBuffer(hDrv, requestNr, ppBuffer)
    if result == 0
        img = copy(get_ImageBufferData(ppBuffer))
        if (error_release = ReleaseImageRequestBufferDesc(ppBuffer)) != 0
            error("Error $error_release releasing image descriptor")
        end
        if (error_unlock = ImageRequestUnlock(hDrv, requestNr)) != 0
            error("Error $error_unlock unlocking request $requestNr")
        end
        img
    else
        error("GetImage failed : $error")
    end
end

function FindList(hDrv, pName, ltype::ListType, flags=0)
    pHList = Ref(Int32(0))
    r = ccall((:DMR_FindList,devicelib), Int32,
              (UInt32, Cstring, Int32, UInt32, Ref{Int32}),
              hDrv, pName, ltype.dmlt, UInt32(flags), pHList)
    check_error(r, "FindList")
    pHList[]
end

function FindList(hDrv, ltype::ListType, flags=0)
    FindList(hDrv, Ptr{Nothing}(), ltype, flags)
end

end

module OBJ
import ..mvIMPACT: devicelib, Cstring_format, check_error

smIgnoreLists = UInt32(0x2)
smIgnoreMethods = UInt32(0x4)
smIgnoreProperties = UInt32(0x8)

vtInt = UInt32(0x1)
vtFloat = UInt32(0x2)
vtPtr = UInt32(0x3)
vtString = UInt32(0x4)
vtInt64 = UInt32(0x5)

struct TComponentType
    ct::UInt32
end
ctProp = TComponentType(0x00010000)
ctList = TComponentType(0x00020000)
ctMeth = TComponentType(0x00040000)
ctPropInt = TComponentType(ctProp.ct | vtInt)
ctPropFloat = TComponentType(ctProp.ct | vtFloat)
ctPropString = TComponentType(ctProp.ct | vtString)
ctPropPtr = TComponentType(ctProp.ct | vtPtr)
ctPropInt64 = TComponentType(ctProp.ct | vtInt64)
ct_dict = Dict(ctProp => "Prop", ctList => "List",
               ctMeth => "Meth", ctPropInt => "PropInt",
               ctPropFloat => "PropFloat", ctPropString => "PropString",
               ctPropPtr => "PropPtr", ctPropInt64 => "PropInt64")

function as_str(ct::TComponentType)
    ct_dict[ct]
end

function GetType(hObj)
    ct = Ref(UInt32(0))
    r = ccall((:OBJ_GetType,devicelib), Int32, (Int32,Ref{UInt32}), hObj, ct)
    check_error(r, "GetType")
    TComponentType(ct[])
end

function GetHandleEx(hList, pObjName, phObj, searchMode, maxSearchDepth)
    ccall((:OBJ_GetHandleEx,devicelib), Int32,
          (Int32,Cstring,Ref{Int32},UInt32,Int32),
          hList, pObjName, phObj, searchMode, maxSearchDepth)
end

function GetI(hProp, index=0)
    pVal = Ref(Int32(0))
    r = ccall((:OBJ_GetI,devicelib), Int32, (Int32,Ref{Int32},UInt32), hProp, pVal, index)
    check_error(r, "GetI")
    pVal[]
end

function GetI64(hProp, index=0)
    pVal = Ref(Int(0))
    r = ccall((:OBJ_GetI64,devicelib), Int32, (Int32,Ref{Int},UInt32), hProp, pVal, index)
    check_error(r, "GetI64")
    pVal[]
end

function GetF(hProp, index=0)
    pVal = Ref(Float64(0))
    r = ccall((:OBJ_GetF,devicelib), Int32, (Int32,Ref{Float64},UInt32), hProp, pVal, index)
    check_error(r, "GetF")
    pVal[]
end

function GetS(hProp, index=0; length=100)
    pVal = zeros(UInt8, length)
    r = ccall((:OBJ_GetS,devicelib), Int32, (Int32,Ref{UInt8},UInt32,UInt32),
              hProp, pVal, length, index)
    check_error(r, "GetS")
    Cstring_format(String(pVal))
end

function SetI(hProp, Val, index=0)
    r = ccall((:OBJ_SetI,devicelib), Int32, (Int32,Int32,UInt32), hProp, Val, index)
    check_error(r, "SetI")
end

function SetF(hProp, Val, index=0)
    r = ccall((:OBJ_SetF,devicelib), Int32, (Int32,Float64,UInt32), hProp, Val, index)
    check_error(r, "SetF")
end

const f_GetContentDesc = (:OBJ_GetContentDesc, devicelib)
const f_GetName = (:OBJ_GetName, devicelib)
const f_GetRepresentationS = (:OBJ_GetRepresentationS, devicelib)

@inline function GetStringProp(hObj, f, length)
    pVal = zeros(UInt8, length)
    r = ccall(f, Int32,
              (Int32,Ref{UInt8},UInt32), hObj, pVal, length)
    check_error(r, "$(f[1])")
    Cstring_format(String(pVal))
end

function GetContentDesc(hObj, length=100)
    GetStringProp(hObj, f_GetContentDesc, length)
end

function GetRepresentationS(hObj, length=100)
    GetStringProp(hObj, f_GetRepresentationS, length)
end

function GetName(hObj, length=100)
    GetStringProp(hObj, f_GetName, length)
end

function GetSArrayFormattedEx(hProp, length=100)
    pBuf = zeros(UInt8, length)
    pbufSize = Ref(Int32(length))
    r = ccall((:OBJ_GetSArrayFormattedEx,devicelib), Int32,
              (Int32,Ptr{UInt8},Ref{Int32},Cstring,Cstring,Int32,Int32,Int32),
              hProp, pBuf, pbufSize, C_NULL, ",", 0, typemax(Int32), 1)
    check_error(r, "GetSArrayFormattedEx")
    Cstring_format(String(pBuf))
end

const f_GetFirstChild = (:OBJ_GetFirstChild, devicelib)
const f_GetFirstSibling = (:OBJ_GetFirstSibling, devicelib)
const f_GetNextSibling = (:OBJ_GetNextSibling, devicelib)
const f_GetLastSibling = (:OBJ_GetLastSibling, devicelib)
const f_GetParent = (:OBJ_GetParent, devicelib)
@inline function Get_OBJ_pOBJ(hObj, f)
    pObj = Ref(Int32(0))
    r = ccall(f, Int32, (Int32,Ref{Int32}), hObj, pObj)
    check_error(r, "$(f[1])")
    pObj[]
end

function GetFirstChild(hObj)
    Get_OBJ_pOBJ(hObj, f_GetFirstChild)
end

function GetFirstSibling(hObj)
    Get_OBJ_pOBJ(hObj, f_GetFirstSibling)
end

function GetNextSibling(hObj)
    Get_OBJ_pOBJ(hObj, f_GetNextSibling)
end

function GetLastSibling(hObj)
    Get_OBJ_pOBJ(hObj, f_GetLastSibling)
end

function GetParent(hObj)
    Get_OBJ_pOBJ(hObj, f_GetParent)
end

function GetSubLists(hObj)
    @assert GetType(hObj) == ctList
    res = []
    curr = GetFirstChild(hObj)
    last = GetLastSibling(curr)
    if GetType(curr) == ctList
        push!(res, GetName(curr))
    end
    while curr != last
        curr = GetNextSibling(curr)
        if GetType(curr) == ctList
            push!(res, GetName(curr))
        end
    end
    res
end

function GetProperties(hObj)
    @assert GetType(hObj) == ctList
    res = []
    curr = GetFirstChild(hObj)
    last = GetLastSibling(curr)
    if GetType(curr).ct & ctProp.ct > 0
        push!(res, GetName(curr))
    end
    while curr != last
        curr = GetNextSibling(curr)
        if GetType(curr).ct & ctProp.ct > 0
            push!(res, GetName(curr))
        end
    end
    res
end

function FindProperty(hList, name)
    @assert GetType(hList) == ctList
    pHandle = Ref(Int32(0))
    r = GetHandleEx(hList, name, pHandle, 0, typemax(Int32))
    check_error(r, "FindProperty")
    pHandle[]
end

function GetDictSize(hProp)
    pDictSize = Ref(UInt32(0))
    r = ccall((:OBJ_GetDictSize, devicelib), Int32, (Int32, Ptr{UInt32}), hProp, pDictSize)
    check_error(r, "GetDictSize")
    pDictSize[]
end

function GetIDictEntry(hProp, index, length=100)
    @assert GetType(hProp) == ctPropInt
    pValue = Ref(Int32(0))
    pTranslationString = zeros(UInt8, length)
    r = ccall((:OBJ_GetIDictEntry, devicelib), Int32,
 	      (Int32,Ptr{UInt8},UInt32,Ptr{Int32},UInt32),
              hProp, pTranslationString, length, pValue, index)
    check_error(r, "GetIDictEntry")
    (Cstring_format(String(pTranslationString)), pValue[])
end

function GetIDictEntries(hProp, length=100)
    @assert GetType(hProp) == ctPropInt
    n = GetDictSize(hProp)
    d = Dict{String,Int32}()
    for i in 0:n-1
        (s,v) = GetIDictEntry(hProp, i, length)
        d[s] = v
    end
    d
end

function ReadProperty(hProp)
    t = GetType(hProp)
    @assert (t.ct & ctProp.ct > 0)
    if t == ctPropInt
        GetI(hProp)
    elseif t == ctPropFloat
        GetF(hProp)
    elseif t == ctPropString
        GetS(hProp)
    elseif t == ctPropInt64
        GetI64(hProp)
    # elseif t == ctPropPtr
    else
        @assert false
    end
end

function WriteProperty(hProp, v)
    t = GetType(hProp)
    vtype = typeof(v)
    @assert (t.ct & ctProp.ct > 0)
    if t == ctPropInt
        if typeof(v) <: Integer
            SetI(hProp, v)
        elseif typeof(v) == String
            d = GetIDictEntries(hProp)
            SetI(hProp, d[v])
        else
            error("Wrong type $vtype for property $(GetName(hProp))")
        end
    elseif t == ctPropFloat
        SetF(hProp, v)
    # elseif t == ctPropString
    #     SetS(hProp)
    # elseif t == ctPropInt64
    #     SetI64(hProp)
    # elseif t == ctPropPtr
    else
        @assert false
    end
end

end

end
