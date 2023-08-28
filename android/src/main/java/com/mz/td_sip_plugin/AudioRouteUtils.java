package com.mz.td_sip_plugin;

import android.os.Build;

import androidx.annotation.RequiresApi;

import org.linphone.core.AudioDevice;
import org.linphone.core.Call;
import org.linphone.core.Conference;
import org.linphone.core.Core;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;


public class AudioRouteUtils {

    Core coreContext;

    public AudioRouteUtils(Core coreContext) {
        this.coreContext = coreContext;
    }

    private void applyAudioRouteChange(Call call, List<AudioDevice.Type> types, Boolean output) {
        Call currentCall = call;
        if (coreContext.getCallsNb() > 0) {
            if (coreContext.getCurrentCall() != null)
                currentCall = coreContext.getCurrentCall();
        }

        Conference conference = coreContext.getConference();
        AudioDevice.Capabilities capability;

        if (output) capability = AudioDevice.Capabilities.CapabilityPlay;
        else capability = AudioDevice.Capabilities.CapabilityRecord;


        String preferredDriver;
        if (output) {
            preferredDriver = coreContext.getDefaultOutputAudioDevice().getDeviceName();
        } else {
            preferredDriver = coreContext.getDefaultInputAudioDevice().getDeviceName();
        }

        AudioDevice[] extendedAudioDevices = coreContext.getExtendedAudioDevices();
        AudioDevice foundAudioDevice = null;
        for (AudioDevice audioDevice : extendedAudioDevices) {
            if (audioDevice.getDriverName().equals(preferredDriver) && types.contains(audioDevice.getType()) && audioDevice.hasCapability(capability)) {
                foundAudioDevice = audioDevice;
            }
        }

        AudioDevice audioDevice = null;

        if (foundAudioDevice == null) {
            for (AudioDevice audioDevice1 : extendedAudioDevices) {
                if (types.contains(audioDevice1.getType()) && audioDevice1.hasCapability(capability)) {
                    audioDevice = audioDevice1;
                }
            }
        } else {
            audioDevice = foundAudioDevice;
        }

        if (audioDevice == null) {
            return;
        }

        if (conference != null && conference.isIn()) {
            if (output) conference.setOutputAudioDevice(audioDevice);
            else conference.setInputAudioDevice(audioDevice);
        } else if (currentCall != null) {
            if (output) currentCall.setOutputAudioDevice(audioDevice);
            else currentCall.setInputAudioDevice(audioDevice);
        } else {
            if (output) coreContext.setOutputAudioDevice(audioDevice);
            else coreContext.setInputAudioDevice(audioDevice);
        }
    }

    private Boolean isBluetoothAudioRecorderAvailable() {
        for (AudioDevice audioDevice : coreContext.getAudioDevices()) {
            if (audioDevice.getType() == AudioDevice.Type.Bluetooth && audioDevice.hasCapability(AudioDevice.Capabilities.CapabilityRecord)) {
                return true;
            }
        }
        return false;
    }

    private Boolean isHeadsetAudioRecorderAvailable() {
        for (AudioDevice audioDevice : coreContext.getAudioDevices()) {
            if ((audioDevice.getType() == AudioDevice.Type.Headset || audioDevice.getType() == AudioDevice.Type.Headphones) && audioDevice.hasCapability(AudioDevice.Capabilities.CapabilityRecord)) {
                return true;
            }
        }
        return false;
    }

    private void changeCaptureDeviceToMatchAudioRoute(Call call, List<AudioDevice.Type> types) {
        if (types.get(0) == AudioDevice.Type.Bluetooth) {
            if (isBluetoothAudioRecorderAvailable()) {
                ArrayList<AudioDevice.Type> array = new ArrayList<>();
                array.add(AudioDevice.Type.Bluetooth);
                applyAudioRouteChange(call, array, false);
            }
        } else if (types.get(0) == AudioDevice.Type.Headset || types.get(0) == AudioDevice.Type.Headphones) {
            if (isHeadsetAudioRecorderAvailable()) {
                ArrayList<AudioDevice.Type> array = new ArrayList<>();
                array.add(AudioDevice.Type.Headphones);
                array.add(AudioDevice.Type.Headset);
                applyAudioRouteChange(call, array, false);
            }
        } else if (types.get(0) == AudioDevice.Type.Earpiece || types.get(0) == AudioDevice.Type.Speaker) {
            ArrayList<AudioDevice.Type> array = new ArrayList<>();
            array.add(AudioDevice.Type.Microphone);
            applyAudioRouteChange(call, array, false);
        }
    }


    private void routeAudioTo(List<AudioDevice.Type> types, Call call) {
        Call currentCall = call;
        if (currentCall == null) {
            currentCall = coreContext.getCurrentCall();
        }
        applyAudioRouteChange(currentCall, types, true);
        changeCaptureDeviceToMatchAudioRoute(call, types);
    }

    public void routeAudioToEarpiece(Call call) {
        ArrayList<AudioDevice.Type> devices = new ArrayList<>();
        devices.add(AudioDevice.Type.Earpiece);
        routeAudioTo(devices, call);
    }

    public void routeAudioToSpeaker(Call call) {
        ArrayList<AudioDevice.Type> devices = new ArrayList<>();
        devices.add(AudioDevice.Type.Speaker);
        routeAudioTo(devices, call);
    }

    public void routeAudioToBluetooth(Call call) {
        ArrayList<AudioDevice.Type> devices = new ArrayList<>();
        devices.add(AudioDevice.Type.Bluetooth);
        routeAudioTo(devices, call);
    }

    public void routeAudioToHeadset(Call call) {
        ArrayList<AudioDevice.Type> devices = new ArrayList<>();
        devices.add(AudioDevice.Type.Headphones);
        routeAudioTo(devices, call);
    }

    public boolean isSpeakerAudioRouteCurrentlyUsed(Call call) {
        if (coreContext.getCallsNb() == 0) {
            return false;
        }
        Conference conference = coreContext.getConference();

        AudioDevice audioDevice = null;

        if (conference != null && conference.isIn())
            audioDevice = conference.getOutputAudioDevice();
        else {
            if (call != null) {
                audioDevice = call.getOutputAudioDevice();
            }
        }
        if (audioDevice != null) {
            return audioDevice.getType() == AudioDevice.Type.Speaker;
        } else return false;
    }

    public boolean isBluetoothAudioRouteCurrentlyUsed(Call call) {
        if (coreContext.getCallsNb() == 0) {
            return false;
        }

        try {
            AudioDevice audioDevice = null;
            audioDevice = call.getOutputAudioDevice();
            return audioDevice.getType() == AudioDevice.Type.Bluetooth;
        } catch (Exception ex) {
            return false;
        }
    }

    public boolean isBluetoothAudioRouteAvailable() {
        for (AudioDevice audioDevice : coreContext.getAudioDevices()) {
            if (audioDevice.getType() == AudioDevice.Type.Bluetooth && audioDevice.hasCapability(AudioDevice.Capabilities.CapabilityPlay)) {
                return true;
            }
        }
        return false;
    }

    public boolean isHeadsetAudioRouteAvailable() {
        for (AudioDevice audioDevice : coreContext.getAudioDevices()) {
            if ((audioDevice.getType() == AudioDevice.Type.Headset || audioDevice.getType() == AudioDevice.Type.Headphones) && audioDevice.hasCapability(AudioDevice.Capabilities.CapabilityPlay)) {
                return true;
            }
        }
        return false;
    }
}
