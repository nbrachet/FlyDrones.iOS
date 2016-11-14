
#ifndef _MAVLINK_H_
#define _MAVLINK_H_

// mavlink.h is very fragile... best to include it first.

#ifndef offsetof
#  define offsetof(type, member)  __builtin_offsetof(type, member)
#endif

/* C99 requires that stdint.h only exposes INT16_MAX if this is defined: */
#ifndef __STDC_LIMIT_MACROS
#  define __STDC_LIMIT_MACROS
#endif

#include "mavlink.h"

static const mavlink_message_info_t mavlink_message_info[256] = MAVLINK_MESSAGE_INFO;

// Auto Pilot modes
// ----------------
// see https://github.com/diydrones/ardupilot/blob/387f3276cb0a04f36255c6128371fc572f0aaaee/ArduCopter/defines.h
enum ARDUCOPTER_MODE
{
    ARDUCOPTER_MODE_STABILIZE=0,    // hold level position
    ARDUCOPTER_MODE_ACRO=1,         // rate control
    ARDUCOPTER_MODE_ALT_HOLD=2,     // AUTO control
    ARDUCOPTER_MODE_AUTO=3,         // AUTO control
    ARDUCOPTER_MODE_GUIDED=4,       // AUTO control
    ARDUCOPTER_MODE_LOITER=5,       // Hold a single location
    ARDUCOPTER_MODE_RTL=6,          // AUTO control
    ARDUCOPTER_MODE_CIRCLE=7,       // AUTO control
    ARDUCOPTER_MODE_LAND=9,         // AUTO control
    ARDUCOPTER_MODE_OF_LOITER=10,   // Hold a single location using optical flow sensor
    ARDUCOPTER_MODE_DRIFT=11,       // DRIFT mode (Note: 12 is no longer used)
    ARDUCOPTER_MODE_SPORT=13,       // earth frame rate control
    ARDUCOPTER_MODE_FLIP=14,        // flip the vehicle on the roll axis
    ARDUCOPTER_MODE_AUTOTUNE=15,    // autotune the vehicle's roll and pitch gains
    ARDUCOPTER_MODE_POSHOLD=16      // position hold with manual override
};

///////////////////////////////////////////////////////////////////////

#ifdef LOGGER_OSTREAM

#include <iomanip>
#include <iostream>

#include <stdio.h> // snprintf
#include <string.h> // strnlen

#ifndef NDEBUG
#  include <stdlib.h> // abort
#endif

    ///////////////////////////////////////////////////////////////////

namespace MavLink {

class IOSFlags
{
public:

    explicit IOSFlags(std::ios_base& s)
        : _s(s)
        , _flags(s.flags())
    {}

    explicit IOSFlags(std::ios_base& s, std::ios_base::fmtflags f)
        : _s(s)
        , _flags(s.setf(f))
    {}

    explicit IOSFlags(std::ios_base& s, std::ios_base::fmtflags f, std::ios_base::fmtflags m)
        : _s(s)
        , _flags(s.setf(f, m))
    {}

    ~IOSFlags()
    {
        restore();
    }

    void restore()
    {
        _s.flags(_flags);
    }

private:

    std::ios_base&                  _s;

    const std::ios_base::fmtflags   _flags;
};

class IOSFill
{
public:

    explicit IOSFill(std::basic_ios<char>& s)
        : _s(s)
        , _fill(s.fill())
    {}

    explicit IOSFill(std::basic_ios<char>& s, char f)
        : _s(s)
        , _fill(s.fill(f))
    {}

    ~IOSFill()
    {
        restore();
    }

    void restore()
    {
        _s.fill(_fill);
    }

private:

    std::basic_ios<char>&           _s;

    const char                      _fill;
};

class IOSWidth
{
public:

    explicit IOSWidth(std::ios_base& s)
        : _s(s)
        , _width(s.width())
    {}

    explicit IOSWidth(std::ios_base& s, std::streamsize w)
        : _s(s)
        , _width(s.width(w))
    {}

    ~IOSWidth()
    {
        restore();
    }

    void restore()
    {
        _s.width(_width);
    }

private:

    std::ios_base&                  _s;

    const std::streamsize           _width;
};

class IOSPrecision
{
public:

    explicit IOSPrecision(std::ios_base& s)
        : _s(s)
        , _precision(s.precision())
    {}

    explicit IOSPrecision(std::ios_base& s, std::streamsize p)
        : _s(s)
        , _precision(s.precision(p))
    {}

    ~IOSPrecision()
    {
        restore();
    }

    void restore()
    {
        _s.precision(_precision);
    }

private:

    std::ios_base&                  _s;

    const std::streamsize           _precision;
};

}

    ///////////////////////////////////////////////////////////////////

inline std::ostream&
operator<<(std::ostream& out, ARDUCOPTER_MODE mode)
{
    switch (mode)
    {
#define DO(x)   case ARDUCOPTER_MODE_##x: return out << #x;

        DO(STABILIZE)
        DO(ACRO)
        DO(ALT_HOLD)
        DO(AUTO)
        DO(GUIDED)
        DO(LOITER)
        DO(RTL)
        DO(CIRCLE)
        DO(LAND)
        DO(OF_LOITER)
        DO(DRIFT)
        DO(SPORT)
        DO(FLIP)
        DO(AUTOTUNE)
        DO(POSHOLD)

#undef DO

    default:    break;
    }
    return out << "ARDUCOPTER_MODE_" << (unsigned)mode;
}

inline std::ostream&
operator<<(std::ostream& out, MAV_TYPE type)
{
    switch (type)
    {
#define DO(x)   case MAV_TYPE_##x: return out << #x;

        DO(GENERIC)
        DO(FIXED_WING)
        DO(QUADROTOR)
        DO(COAXIAL)
        DO(HELICOPTER)
        DO(ANTENNA_TRACKER)
        DO(GCS)
        DO(AIRSHIP)
        DO(FREE_BALLOON)
        DO(ROCKET)
        DO(GROUND_ROVER)
        DO(SURFACE_BOAT)
        DO(SUBMARINE)
        DO(HEXAROTOR)
        DO(OCTOROTOR)
        DO(TRICOPTER)
        DO(FLAPPING_WING)
        DO(KITE)
        DO(ONBOARD_CONTROLLER)

#undef DO

    default:    break;
    }
    return out << "MAV_TYPE_" << (unsigned)type;
}

inline std::ostream&
operator<<(std::ostream& out, MAV_AUTOPILOT autopilot)
{
    switch (autopilot)
    {
#define DO(x)   case MAV_AUTOPILOT_##x: return out << #x;

        DO(GENERIC)
#ifdef MAVLINK_ENABLED_PIXHAWK
        DO(PIXHAWK)
#else
        DO(RESERVED) // used to be PIXHAWK
#endif
        DO(SLUGS)
        DO(ARDUPILOTMEGA)
        DO(OPENPILOT)
        DO(GENERIC_WAYPOINTS_ONLY)
        DO(GENERIC_WAYPOINTS_AND_SIMPLE_NAVIGATION_ONLY)
        DO(GENERIC_MISSION_FULL)
        DO(INVALID)
        DO(PPZ)
        DO(UDB)
        DO(FP)
        DO(PX4)
        DO(SMACCMPILOT)
        DO(AUTOQUAD)
        DO(ARMAZILA)
        DO(AEROB)
        DO(ASLUAV)

#undef DO

        default:    break;
    }
    return out << "MAV_AUTOPILOT_" << (unsigned)autopilot;
}

inline std::ostream&
operator<<(std::ostream& out, MAV_MODE_FLAG mode)
{
    bool first = true;

#define DO(x, y)                        \
    if (mode & (MAV_MODE_FLAG_##x))     \
    {                                   \
        if (! first)                    \
            out << '|';                 \
        else                            \
            first = false;              \
        out << #y;                      \
    }

    DO(CUSTOM_MODE_ENABLED, CUSTOM_MODE)
    DO(TEST_ENABLED, TEST)
    DO(AUTO_ENABLED, AUTO)
    DO(GUIDED_ENABLED, GUIDED)
    DO(STABILIZE_ENABLED, STABILIZE)
    DO(HIL_ENABLED, HIL)
    DO(MANUAL_INPUT_ENABLED, MANUAL_INPUT)
    DO(SAFETY_ARMED, ARMED)

#undef DO

    return out;
}

inline std::ostream&
operator<<(std::ostream& out, MAV_STATE state)
{
    switch (state)
    {
#define DO(x)   case MAV_STATE_##x: return out << #x;

        DO(UNINIT)
        DO(BOOT)
        DO(CALIBRATING)
        DO(STANDBY)
        DO(ACTIVE)
        DO(CRITICAL)
        DO(EMERGENCY)
        DO(POWEROFF)

#undef DO

        default:    break;
    }
    return out << (unsigned)state;
}

inline std::ostream&
operator<<(std::ostream& out, const mavlink_heartbeat_t& msg)
{
    if (! out)
        return out;

    out << "custom_mode=" << msg.custom_mode;
    if (msg.autopilot == (uint8_t)MAV_AUTOPILOT_ARDUPILOTMEGA)
        out << " (" << (ARDUCOPTER_MODE)msg.custom_mode << ')';
    out << ' ';

    out << "type=" << (MAV_TYPE)msg.type << ' '
        << "autopilot=" << (MAV_AUTOPILOT)msg.autopilot << ' '
        << "base_mode=" << (MAV_MODE_FLAG)msg.base_mode << ' '
        << "system_status=" << (MAV_STATE)msg.system_status << ' '
        << "mavlink_version=" << (unsigned)msg.mavlink_version;
    return out;
}

    ///////////////////////////////////////////////////////////////////

inline std::ostream&
operator<<(std::ostream& out, const mavlink_set_mode_t& msg)
{
    if (! out)
        return out;

    out << "custom_mode=" << msg.custom_mode
        << " (" << (ARDUCOPTER_MODE)msg.custom_mode << ") " // FIXME: only if it is ARDUCOPTER
        << "target_system=" << (unsigned)msg.target_system << ' '
        << "base_mode=" << (MAV_MODE_FLAG)msg.base_mode;
    return out;
}

    ///////////////////////////////////////////////////////////////////

namespace {

struct _MavSysStatusSensor
{
    uint32_t m; // mask (ie. all bits present)
    uint32_t x; // value (ie. all bits to be printed)

    explicit _MavSysStatusSensor(uint32_t _x)
        : m(_x), x(_x)
    {}

    explicit _MavSysStatusSensor(uint32_t _m, uint32_t _x)
        : m(_m & _x), x(_m & ~_x)
    {}

    friend std::ostream& operator<<(std::ostream& out, const _MavSysStatusSensor& that)
    {
        if (that.m == 0)
            return out << "(*none*)";
        if (that.x == 0)
            return out << "(*all*)";

        unsigned n = 0;
        const char* sep = (that.m == that.x ? "(" : "!(");

#define DO(b)                                           \
    if ((that.x & MAV_SYS_STATUS_SENSOR_##b) != 0)      \
    {                                                   \
        out << sep;                                     \
        if (n++ == 0)                                   \
            sep = (that.m == that.x ? "|" : "&");       \
        out << #b;                                      \
    }

        DO(3D_GYRO)
        DO(3D_ACCEL)
        DO(3D_MAG)
        DO(ABSOLUTE_PRESSURE)
        DO(DIFFERENTIAL_PRESSURE)
        DO(GPS)
        DO(OPTICAL_FLOW)
        DO(VISION_POSITION)
        DO(LASER_POSITION)
        DO(EXTERNAL_GROUND_TRUTH)
        DO(ANGULAR_RATE_CONTROL)
        DO(ATTITUDE_STABILIZATION)
        DO(YAW_POSITION)
        DO(Z_ALTITUDE_CONTROL)
        DO(XY_POSITION_CONTROL)
        DO(MOTOR_OUTPUTS)
        DO(RC_RECEIVER)
        DO(3D_GYRO2)
        DO(3D_ACCEL2)
        DO(3D_MAG2)

#undef DO

#define DO(b)                                           \
    if ((that.x & MAV_SYS_STATUS_##b) != 0)             \
    {                                                   \
        out << sep;                                     \
        if (n++ == 0)                                   \
            sep = (that.m == that.x ? "|" : "&");       \
        out << #b;                                      \
    }

        DO(GEOFENCE)
        DO(AHRS)
        DO(TERRAIN)

#undef DO

        if (n == 0)
            out << "(*none*)";
        else
            out << ')';

        return out;
    }
};

}

inline std::ostream&
operator<<(std::ostream& out, const mavlink_sys_status_t& msg)
{
    if (! out)
        return out;

    MavLink::IOSFlags iosflags(out, std::ios_base::fixed, std::ios_base::floatfield);
    MavLink::IOSPrecision precision(out);

    out << "onboard_control_sensors_present=" << _MavSysStatusSensor(msg.onboard_control_sensors_present) << ' '
        << "onboard_control_sensors_enabled=" << _MavSysStatusSensor(msg.onboard_control_sensors_present, msg.onboard_control_sensors_enabled) << ' '
        << "onboard_control_sensors_health=" << _MavSysStatusSensor(msg.onboard_control_sensors_enabled, msg.onboard_control_sensors_health) << ' '
        << "load=" << std::setprecision(1) << msg.load / 10.0 << "% "
        << "voltage_battery=" << std::setprecision(3) << msg.voltage_battery * 0.001 << "V ";
    if (msg.current_battery != -1)
        out << "current_battery=" << std::setprecision(2) << msg.current_battery * 0.01 << "A ";
    out << "drop_rate_comm=" << std::setprecision(2) << msg.drop_rate_comm / 100.0 << "% "
        << "errors_comm=" << msg.errors_comm << ' '
        << "errors_count1=" << msg.errors_count1 << ' '
        << "errors_count2=" << msg.errors_count2 << ' '
        << "errors_count3=" << msg.errors_count3 << ' '
        << "errors_count4=" << msg.errors_count4 << ' ';
    if (msg.battery_remaining != -1)
        out << "battery_remaining=" << (unsigned)msg.battery_remaining << '%';
    return out;
}

    ///////////////////////////////////////////////////////////////////

inline std::ostream&
operator<<(std::ostream& out, const mavlink_battery_status_t& msg)
{
    if (! out)
        return out;

    MavLink::IOSFlags iosflags(out, std::ios_base::fixed, std::ios_base::floatfield);
    MavLink::IOSPrecision precision(out);

    if (msg.current_consumed != -1)
        out << "current_consumed=" << msg.current_consumed << "mAh ";
    if (msg.energy_consumed != -1)
        out << "energy_consumed=" << std::setprecision(2) << msg.energy_consumed / 100.0 << "J ";
    if (msg.temperature != INT16_MAX)
        out << "temperature=" << std::setprecision(2) << msg.temperature / 100.0 << "C ";

    unsigned voltage = 0;
    for (unsigned i = 0; i < 10; ++i)
        voltage += msg.voltages[i];
    out << "voltage=" << std::setprecision(3) << voltage / 1000.0 << "V (";
    for (unsigned i = 0; i < 10; ++i)
    {
        if (i > 0)
            out << '+';
        out << /* std::setprecision(3) << */ msg.voltages[i] / 1000.0;
    }
    out << ") ";

    if (msg.current_battery != -1)
        out << "current_battery=" << std::setprecision(2) << msg.current_battery / 100.0 << "A ";
    out << "id=" << (unsigned)msg.id << ' '
        << "function=" << (unsigned)msg.battery_function << ' '
        << "type=" << (unsigned)msg.type;
    if (msg.battery_remaining != -1)
        out << " battery_remaining=" << (unsigned)msg.battery_remaining << '%';

    return out;
}

    ///////////////////////////////////////////////////////////////////

inline std::ostream&
operator<<(std::ostream& out, MAV_DATA_STREAM data_stream)
{
    switch (data_stream)
    {
#define DO(x)   case MAV_DATA_STREAM_##x:   return out << #x;

    DO(ALL)
    DO(RAW_SENSORS)
    DO(EXTENDED_STATUS)
    DO(RC_CHANNELS)
    DO(RAW_CONTROLLER)
    DO(POSITION)
    DO(EXTRA1)
    DO(EXTRA2)
    DO(EXTRA3)

#undef DO

    default:    break;
    }
    return out << "MAV_DATA_STREAM_" << (unsigned) data_stream;
}

inline std::ostream&
operator<<(std::ostream& out, const mavlink_request_data_stream_t& msg)
{
    if (! out)
        return out;

    out << "req_message_rate=" << msg.req_message_rate << ' '
        << "target_system=" << (unsigned)msg.target_system << ' '
        << "target_component=" << (unsigned)msg.target_component << ' '
        << "req_stream_id=" << (MAV_DATA_STREAM)msg.req_stream_id << ' '
        << (msg.start_stop ? "START" : "STOP");

    return out;
}

    ///////////////////////////////////////////////////////////////////

inline std::ostream&
operator<<(std::ostream& out, MAV_CMD cmd)
{
    switch (cmd)
    {
#define DO(x)   case MAV_CMD_##x: return out << #x;

        DO(NAV_WAYPOINT)                    // 16
        DO(NAV_LOITER_UNLIM)                // 17
        DO(NAV_LOITER_TURNS)                // 18
        DO(NAV_LOITER_TIME)                 // 19
        DO(NAV_RETURN_TO_LAUNCH)            // 20
        DO(NAV_LAND)                        // 21
        DO(NAV_TAKEOFF)                     // 22
        DO(NAV_LAND_LOCAL)                  // 23
        DO(NAV_TAKEOFF_LOCAL)               // 24
        DO(NAV_FOLLOW)                      // 25
        DO(NAV_CONTINUE_AND_CHANGE_ALT)     // 30
        DO(NAV_LOITER_TO_ALT)               // 31
        DO(DO_FOLLOW)                       // 32
        DO(DO_FOLLOW_REPOSITION)            // 33
        DO(NAV_ROI)                         // 80
        DO(NAV_PATHPLANNING)                // 81
        DO(NAV_SPLINE_WAYPOINT)             // 82
        DO(NAV_VTOL_TAKEOFF)                // 84
        DO(NAV_VTOL_LAND)                   // 85
        DO(NAV_GUIDED_ENABLE)               // 92
        DO(NAV_DELAY)                       // 93
        DO(NAV_LAST)                        // 95
        DO(CONDITION_DELAY)                 // 112
        DO(CONDITION_CHANGE_ALT)            // 113
        DO(CONDITION_DISTANCE)              // 114
        DO(CONDITION_YAW)                   // 115
        DO(CONDITION_LAST)                  // 159
        DO(DO_SET_MODE)                     // 176
        DO(DO_JUMP)                         // 177
        DO(DO_CHANGE_SPEED)                 // 178
        DO(DO_SET_HOME)                     // 179
        DO(DO_SET_PARAMETER)                // 180
        DO(DO_SET_RELAY)                    // 181
        DO(DO_REPEAT_RELAY)                 // 182
        DO(DO_SET_SERVO)                    // 183
        DO(DO_REPEAT_SERVO)                 // 184
        DO(DO_FLIGHTTERMINATION)            // 185
        DO(DO_LAND_START)                   // 189
        DO(DO_RALLY_LAND)                   // 190
        DO(DO_GO_AROUND)                    // 191
        DO(DO_REPOSITION)                   // 192
        DO(DO_PAUSE_CONTINUE)               // 193
        DO(DO_CONTROL_VIDEO)                // 200
        DO(DO_SET_ROI)                      // 201
        DO(DO_DIGICAM_CONFIGURE)            // 202
        DO(DO_DIGICAM_CONTROL)              // 203
        DO(DO_MOUNT_CONFIGURE)              // 204
        DO(DO_MOUNT_CONTROL)                // 205
        DO(DO_SET_CAM_TRIGG_DIST)           // 206
        DO(DO_FENCE_ENABLE)                 // 207
        DO(DO_PARACHUTE)                    // 208
        DO(DO_INVERTED_FLIGHT)              // 210
        DO(DO_MOUNT_CONTROL_QUAT)           // 220
        DO(DO_GUIDED_MASTER)                // 221
        DO(DO_GUIDED_LIMITS)                // 222
        DO(DO_LAST)                         // 240
        DO(PREFLIGHT_CALIBRATION)           // 241
        DO(PREFLIGHT_SET_SENSOR_OFFSETS)    // 242
        DO(PREFLIGHT_UAVCAN)                // 243
        DO(PREFLIGHT_STORAGE)               // 245
        DO(PREFLIGHT_REBOOT_SHUTDOWN)       // 246
        DO(OVERRIDE_GOTO)                   // 252
        DO(MISSION_START)                   // 300
        DO(COMPONENT_ARM_DISARM)            // 400
        DO(GET_HOME_POSITION)               // 410
        DO(START_RX_PAIR)                   // 500
        DO(GET_MESSAGE_INTERVAL)            // 510
        DO(SET_MESSAGE_INTERVAL)            // 511
        DO(REQUEST_AUTOPILOT_CAPABILITIES)  // 520
        DO(IMAGE_START_CAPTURE)             // 2000
        DO(IMAGE_STOP_CAPTURE)              // 2001
        DO(DO_TRIGGER_CONTROL)              // 2003
        DO(VIDEO_START_CAPTURE)             // 2500
        DO(VIDEO_STOP_CAPTURE)              // 2501
        DO(PANORAMA_CREATE)                 // 2800
        DO(DO_VTOL_TRANSITION)              // 3000
        DO(PAYLOAD_PREPARE_DEPLOY)          // 30001
        DO(PAYLOAD_CONTROL_DEPLOY)          // 30002
        DO(WAYPOINT_USER_1)                 // 31000
        DO(WAYPOINT_USER_2)                 // 31001
        DO(WAYPOINT_USER_3)                 // 31002
        DO(WAYPOINT_USER_4)                 // 31003
        DO(WAYPOINT_USER_5)                 // 31004
        DO(SPATIAL_USER_1)                  // 31005
        DO(SPATIAL_USER_2)                  // 31006
        DO(SPATIAL_USER_3)                  // 31007
        DO(SPATIAL_USER_4)                  // 31008
        DO(SPATIAL_USER_5)                  // 31009
        DO(USER_1)                          // 31010
        DO(USER_2)                          // 31011
        DO(USER_3)                          // 31012
        DO(USER_4)                          // 31013
        DO(USER_5)                          // 31014

#ifdef MAVLINK_ENABLED_ARDUPILOTMEGA
        DO(NAV_ALTITUDE_WAIT)               // 83
        DO(DO_MOTOR_TEST)                   // 209
        DO(DO_GRIPPER)                      // 211
        DO(DO_AUTOTUNE_ENABLE)              // 212
        DO(POWER_OFF_INITIATED)             // 42000
        DO(SOLO_BTN_FLY_CLICK)              // 42001
        DO(SOLO_BTN_FLY_HOLD)               // 42002
        DO(SOLO_BTN_PAUSE_CLICK)            // 42003
        DO(DO_START_MAG_CAL)                // 42424
        DO(DO_ACCEPT_MAG_CAL)               // 42425
        DO(DO_CANCEL_MAG_CAL)               // 42426
        DO(SET_FACTORY_TEST_MODE)           // 42427
        DO(DO_SEND_BANNER)                  // 42428
        DO(GIMBAL_RESET)                    // 42501
        DO(GIMBAL_AXIS_CALIBRATION_STATUS)  // 42502
        DO(GIMBAL_REQUEST_AXIS_CALIBRATION) // 42503
        DO(GIMBAL_FULL_RESET)               // 42505
#endif

#undef DO

        case MAV_CMD_ENUM_END:
            break;
    }
    return out << "MAV_CMD_" << (uint16_t)cmd;
}

inline std::ostream&
operator<<(std::ostream& out, const mavlink_command_long_t& msg)
{
    if (! out)
        return out;

    out << (MAV_CMD)msg.command << ':'
        << " target_sys=" << (unsigned)msg.target_system
        << " target_comp=" << (unsigned)msg.target_component;

    switch (msg.command)
    {
    case MAV_CMD_PREFLIGHT_CALIBRATION:
        out << " Gyro=" << (bool)msg.param1
            << " Magnetometer=" << (bool)msg.param2
            << " Ground pressure=" << (bool)msg.param3
            << " Radio=" << (bool)msg.param4
            << " Accelerometer=" << (bool)msg.param5
            << " Compass/Motor interference=" << (bool)msg.param6;
        break;

    case MAV_CMD_COMPONENT_ARM_DISARM:
        if (msg.param1)
            out << " ARM";
        else
            out << " DISARM";
        break;

    default:
        out << " param1=" << msg.param1
            << " param2=" << msg.param2
            << " param3=" << msg.param3
            << " param4=" << msg.param4
            << " param5=" << msg.param5
            << " param6=" << msg.param6
            << " param7=" << msg.param7;
        break;
    }

    out << " confirmation=" << (unsigned)msg.confirmation;

    return out;
}

inline std::ostream&
operator<<(std::ostream& out, MAV_RESULT result)
{
    switch (result)
    {
#define DO(x)   case MAV_RESULT_##x: return out << #x;

        DO(ACCEPTED)
        DO(TEMPORARILY_REJECTED)
        DO(DENIED)
        DO(UNSUPPORTED)
        DO(FAILED)

#undef DO

        case MAV_RESULT_ENUM_END:
            break;
    }
    return out << "MAV_RESULT_" << (uint16_t)result;
}

inline std::ostream&
operator<<(std::ostream& out, const mavlink_command_ack_t& msg)
{
    if (! out)
        return out;

    return out << (MAV_CMD)msg.command << ": " << (MAV_RESULT)msg.result;
}

    ///////////////////////////////////////////////////////////////////

inline std::ostream&
operator<<(std::ostream& out, const mavlink_message_t& msg)
{
    if (! out)
        return out;

    MavLink::IOSWidth width(out);

    out << "SEQ:" << std::setw(3) << (unsigned)msg.seq
        << " SYSID:" << std::setw(3) << (unsigned)msg.sysid
        << " COMPID:" << std::setw(3) << (unsigned)msg.compid;

    const mavlink_message_info_t* info = &mavlink_message_info[msg.msgid];
    if (info == NULL)
        return out << " MSGID:" << std::setw(3) << (unsigned)msg.msgid;

    width.restore();

    out << " - " << info->name << ": ";

    switch (msg.msgid)
    {
    case MAVLINK_MSG_ID_HEARTBEAT:
        return out << *reinterpret_cast<const mavlink_heartbeat_t*>(_MAV_PAYLOAD(&msg));
    case MAVLINK_MSG_ID_SYS_STATUS:
        return out << *reinterpret_cast<const mavlink_sys_status_t*>(_MAV_PAYLOAD(&msg));
    case MAVLINK_MSG_ID_BATTERY_STATUS:
        return out << *reinterpret_cast<const mavlink_battery_status_t*>(_MAV_PAYLOAD(&msg));
    case MAVLINK_MSG_ID_REQUEST_DATA_STREAM:
        return out << *reinterpret_cast<const mavlink_request_data_stream_t*>(_MAV_PAYLOAD(&msg));
    case MAVLINK_MSG_ID_SET_MODE:
        return out << *reinterpret_cast<const mavlink_set_mode_t*>(_MAV_PAYLOAD(&msg));
    case MAVLINK_MSG_ID_COMMAND_LONG:
        return out << *reinterpret_cast<const mavlink_command_long_t*>(_MAV_PAYLOAD(&msg));
    case MAVLINK_MSG_ID_COMMAND_ACK:
        return out << *reinterpret_cast<const mavlink_command_ack_t*>(_MAV_PAYLOAD(&msg));
    }

    for (unsigned i = 0; i < info->num_fields; ++i)
    {
        if (i > 0)
            out << ' ';

        const mavlink_field_info_t* field = &info->fields[i];
        out << field->name << '=';

        if (field->array_length > 0)
        {
            switch (field->type)
            {
            case MAVLINK_TYPE_CHAR:
            {
                out << '"';
                const char* s = _MAV_PAYLOAD(&msg) + field->wire_offset;
                if (strnlen(s, field->array_length) < field->array_length)
                    out << s;
                else
                    out.write(s, field->array_length);
                out << '"';
                break;
            }

            default:
                out << '[' << field->array_length << ']';
                break;
            }
            continue;
        }

        if (field->print_format != NULL)
        {
            char buf[32];
            int n;
            switch (field->type)
            {
            case MAVLINK_TYPE_CHAR:
                n = snprintf(buf, sizeof(buf), field->print_format, _MAV_RETURN_char(&msg, field->wire_offset));
                break;

            case MAVLINK_TYPE_UINT8_T:
                n = snprintf(buf, sizeof(buf), field->print_format, _MAV_RETURN_uint8_t(&msg, field->wire_offset));
                break;

            case MAVLINK_TYPE_INT8_T:
                n = snprintf(buf, sizeof(buf), field->print_format, _MAV_RETURN_int8_t(&msg, field->wire_offset));
                break;

            case MAVLINK_TYPE_UINT16_T:
                n = snprintf(buf, sizeof(buf), field->print_format, _MAV_RETURN_uint16_t(&msg, field->wire_offset));
                break;

            case MAVLINK_TYPE_INT16_T:
                n = snprintf(buf, sizeof(buf), field->print_format, _MAV_RETURN_int16_t(&msg, field->wire_offset));
                break;

            case MAVLINK_TYPE_UINT32_T:
                n = snprintf(buf, sizeof(buf), field->print_format, _MAV_RETURN_uint32_t(&msg, field->wire_offset));
                break;

            case MAVLINK_TYPE_INT32_T:
                n = snprintf(buf, sizeof(buf), field->print_format, _MAV_RETURN_int32_t(&msg, field->wire_offset));
                break;

            case MAVLINK_TYPE_UINT64_T:
                n = snprintf(buf, sizeof(buf), field->print_format, _MAV_RETURN_uint64_t(&msg, field->wire_offset));
                break;

            case MAVLINK_TYPE_INT64_T:
                n = snprintf(buf, sizeof(buf), field->print_format, _MAV_RETURN_int64_t(&msg, field->wire_offset));
                break;

            case MAVLINK_TYPE_FLOAT:
                n = snprintf(buf, sizeof(buf), field->print_format, _MAV_RETURN_float(&msg, field->wire_offset));
                break;

            case MAVLINK_TYPE_DOUBLE:
                n = snprintf(buf, sizeof(buf), field->print_format, _MAV_RETURN_double(&msg, field->wire_offset));
                break;

            default:
                n = 0;
                break;
            }

#ifdef LOGGER_ASSERT
            LOGGER_ASSERT(n < (int)sizeof(buf));
#elif defined(assert)
            assert(n < (int)sizeof(buf));
#elif !defined(NDEBUG)
            if (! (n < (int)sizeof(buf)))
                abort();
#endif

            if (n > 0)
                out << buf;
        }
        else
        {
            switch (field->type)
            {
            case MAVLINK_TYPE_CHAR:
                out << _MAV_RETURN_char(&msg, field->wire_offset);
                break;

            case MAVLINK_TYPE_UINT8_T:
                out << (unsigned)_MAV_RETURN_uint8_t(&msg, field->wire_offset);
                break;

            case MAVLINK_TYPE_INT8_T:
                out << (int)_MAV_RETURN_int8_t(&msg, field->wire_offset);
                break;

            case MAVLINK_TYPE_UINT16_T:
                out << _MAV_RETURN_uint16_t(&msg, field->wire_offset);
                break;

            case MAVLINK_TYPE_INT16_T:
                out << _MAV_RETURN_int16_t(&msg, field->wire_offset);
                break;

            case MAVLINK_TYPE_UINT32_T:
                out << _MAV_RETURN_uint32_t(&msg, field->wire_offset);
                break;

            case MAVLINK_TYPE_INT32_T:
                out << _MAV_RETURN_int32_t(&msg, field->wire_offset);
                break;

            case MAVLINK_TYPE_UINT64_T:
                out << _MAV_RETURN_uint64_t(&msg, field->wire_offset);
                break;

            case MAVLINK_TYPE_INT64_T:
                out << _MAV_RETURN_int64_t(&msg, field->wire_offset);
                break;

            case MAVLINK_TYPE_FLOAT:
                out << _MAV_RETURN_float(&msg, field->wire_offset);
                break;

            case MAVLINK_TYPE_DOUBLE:
                out << _MAV_RETURN_double(&msg, field->wire_offset);
                break;
            }
        }
    }

    return out;
}

#endif // LOGGER_OSTREAM

#endif
