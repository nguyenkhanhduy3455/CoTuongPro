import numpy as np
import scipy.io.wavfile as wav
import os

sample_rate = 44100

def create_war_move_sound():
    # 0.45 seconds: crisp, high impact, audible on mobile speakers
    duration = 0.45
    t = np.linspace(0, duration, int(sample_rate * duration), False)
    
    # 1. Audible Mid-Bass Punch (180Hz down to 80Hz - audible on phone speakers)
    punch_pitch = 180.0 * np.exp(-t * 25.0) + 75.0
    punch_phase = 2 * np.pi * np.cumsum(punch_pitch) / sample_rate
    punch_body = np.sin(punch_phase) * np.exp(-t * 12.0)
    punch_body += 0.5 * np.sin(punch_phase * 2.0) * np.exp(-t * 16.0)
    
    # 2. Strong Hardwood Slam (Tiếng quân cờ gỗ đập bàn uy lực)
    # Resonances at 450Hz, 850Hz, 1350Hz, 2100Hz
    wood_env = np.exp(-t * 28.0)
    wood_snap = (
        0.75 * np.sin(2 * np.pi * 480 * t) +
        0.65 * np.sin(2 * np.pi * 880 * t) +
        0.50 * np.sin(2 * np.pi * 1420 * t) +
        0.35 * np.sin(2 * np.pi * 2250 * t)
    ) * wood_env
    
    # Sharp initial attack transient (0-15ms)
    transient_len = int(0.015 * sample_rate)
    wood_snap[:transient_len] += np.random.uniform(-0.8, 0.8, transient_len) * np.linspace(1, 0, transient_len)
    
    # 3. Martial Shimmer / Blade Zing (Khí chất sa trường)
    metal_env = np.exp(-t * 10.0)
    metal_ring = (
        0.28 * np.sin(2 * np.pi * 2650 * t) +
        0.22 * np.sin(2 * np.pi * 3820 * t) +
        0.15 * np.sin(2 * np.pi * 5100 * t)
    ) * metal_env
    
    # Combine & master
    combined = 0.85 * punch_body + 1.1 * wood_snap + 0.45 * metal_ring
    # Soft saturation for thickness
    combined = np.tanh(combined * 1.6)
    
    # Stereo width with subtle room reflection
    delay = int(0.02 * sample_rate)
    echo = np.zeros_like(combined)
    echo[delay:] = combined[:-delay] * 0.25
    
    left = combined + echo * 0.7
    right = combined + echo * 1.1
    
    stereo = np.column_stack([left, right])
    max_val = np.max(np.abs(stereo))
    if max_val > 0:
        stereo = (stereo / max_val) * 0.98  # Maximum clean headroom
        
    return (stereo * 32767).astype(np.int16)

def create_capture_sound():
    # 0.55 seconds: heavy blade clash + war drum + piece crush
    duration = 0.55
    t = np.linspace(0, duration, int(sample_rate * duration), False)
    
    # 1. War drum impact (audible on phones)
    drum_pitch = 220.0 * np.exp(-t * 22.0) + 70.0
    drum_phase = 2 * np.pi * np.cumsum(drum_pitch) / sample_rate
    sub_thud = (np.sin(drum_phase) + 0.6 * np.sin(drum_phase * 2.0)) * np.exp(-t * 10.0)
    
    # 2. Heavy Wood Impact
    wood_env = np.exp(-t * 24.0)
    wood_clack = (
        0.8 * np.sin(2 * np.pi * 520 * t) +
        0.6 * np.sin(2 * np.pi * 960 * t) +
        0.4 * np.sin(2 * np.pi * 1650 * t)
    ) * wood_env
    
    # 3. Fierce Blade Strike & Spark Burst
    blade_env = np.exp(-t * 7.0)
    blade = (
        0.55 * np.sin(2 * np.pi * 1950 * t) +
        0.45 * np.sin(2 * np.pi * 3100 * t) +
        0.30 * np.sin(2 * np.pi * 4600 * t) +
        0.20 * np.sin(2 * np.pi * 6200 * t)
    ) * blade_env
    
    noise_len = int(0.03 * sample_rate)
    burst = np.zeros_like(t)
    burst[:noise_len] = np.random.uniform(-0.9, 0.9, noise_len) * np.linspace(1, 0, noise_len)
    
    combined = 0.9 * sub_thud + 0.95 * wood_clack + 0.7 * blade + 0.45 * burst
    combined = np.tanh(combined * 1.8)
    
    delay = int(0.025 * sample_rate)
    echo = np.zeros_like(combined)
    echo[delay:] = combined[:-delay] * 0.3
    
    left = combined + echo * 0.8
    right = combined + echo * 1.2
    
    stereo = np.column_stack([left, right])
    max_val = np.max(np.abs(stereo))
    if max_val > 0:
        stereo = (stereo / max_val) * 0.98
        
    return (stereo * 32767).astype(np.int16)

def create_select_sound():
    # 0.12 seconds: subtle tactile piece lift / touch
    duration = 0.12
    t = np.linspace(0, duration, int(sample_rate * duration), False)
    
    wood_env = np.exp(-t * 55.0)
    tap = (
        0.6 * np.sin(2 * np.pi * 720 * t) +
        0.4 * np.sin(2 * np.pi * 1380 * t)
    ) * wood_env
    
    tap_len = int(0.006 * sample_rate)
    tap[:tap_len] += np.random.uniform(-0.4, 0.4, tap_len) * np.linspace(1, 0, tap_len)
    
    combined = np.tanh(tap * 1.5)
    stereo = np.column_stack([combined, combined])
    max_val = np.max(np.abs(stereo))
    if max_val > 0:
        stereo = (stereo / max_val) * 0.85
        
    return (stereo * 32767).astype(np.int16)

os.makedirs("Game/assets/audio", exist_ok=True)
move_data = create_war_move_sound()
capture_data = create_capture_sound()
select_data = create_select_sound()

wav.write("Game/assets/audio/move.wav", sample_rate, move_data)
wav.write("Game/assets/audio/capture.wav", sample_rate, capture_data)
wav.write("Game/assets/audio/select.wav", sample_rate, select_data)
print("Generated move.wav, capture.wav, and select.wav successfully.")
