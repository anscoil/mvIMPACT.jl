using PyPlot

using mvIMPACT

DMR.Init()
DevCnt = DMR.getDeviceCount()
println("$(DevCnt) devices detected")

hDev = DMR.GetDeviceNr(0)

info = DMR.GetDeviceInfoEx(hDev, DMR.dmditDeviceInfoStructure)
println(info.serial)
println(info.family)
println(info.product)
println(info.firmwareVersion)

println("Opening device $hDev")
hDrv = DMR.OpenDevice(hDev)

hList = DMR.FindList(hDrv, DMR.dmltSetting)
println("hList of type: ", OBJ.as_str(OBJ.GetType(hList)))
println(OBJ.GetContentDesc(hList))
hGain = OBJ.FindProperty(hList, "Gain_dB")
println(OBJ.GetName(hGain), " of type ", OBJ.as_str(OBJ.GetType(hGain)),
        " has value ", OBJ.ReadProperty(hGain))
hExposure = OBJ.FindProperty(hList, "Expose_us")
println(OBJ.GetName(hExposure), " of type ", OBJ.as_str(OBJ.GetType(hExposure)),
        " has value ", OBJ.ReadProperty(hExposure))
hPixelFormat = OBJ.FindProperty(hList, "PixelFormat")
println(OBJ.GetName(hPixelFormat), " of type ", OBJ.as_str(OBJ.GetType(hPixelFormat)),
        " has value ", OBJ.ReadProperty(hPixelFormat))

hW = OBJ.FindProperty(hList, "W")
println(OBJ.GetName(hW), " of type ", OBJ.as_str(OBJ.GetType(hW)),
        " has value ", OBJ.ReadProperty(hW))
hH = OBJ.FindProperty(hList, "H")
println(OBJ.GetName(hH), " of type ", OBJ.as_str(OBJ.GetType(hH)),
        " has value ", OBJ.ReadProperty(hH))

println("Gain dict size: ", OBJ.GetDictSize(hGain))
println("Exposure dict size: ", OBJ.GetDictSize(hExposure))
println("PixelFormat dict size: ", OBJ.GetDictSize(hPixelFormat))

OBJ.WriteProperty(hGain, 0)
OBJ.WriteProperty(hExposure, 1000)
println(OBJ.GetIDictEntries(hPixelFormat))
OBJ.WriteProperty(hPixelFormat, "Mono10")

println("\t", OBJ.ReadProperty(hGain), "\n",
        "\t", OBJ.ReadProperty(hExposure), "\n",
        "\t", OBJ.ReadProperty(hPixelFormat))

l_imgs = []

@time for i in 1:10
    img = DMR.GetImage(hDrv)
    push!(l_imgs, img)
end

figure()
imshow(l_imgs[1])
colorbar()
figure()
imshow(l_imgs[end])
colorbar()

show()

println("Closing device $hDev with driver $hDrv")
DMR.CloseDevice(hDrv, hDev)
DMR.Close()
