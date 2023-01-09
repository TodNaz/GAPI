/*
  * Copyright (c) 2007-2009 Intel Corporation. All Rights Reserved.
  *
  * Permission is hereby granted, free of charge, to any person obtaining a
  * copy of this software and associated documentation files (the
  * "Software"), to deal in the Software without restriction, including
  * without limitation the rights to use, copy, modify, merge, publish,
  * distribute, sub license, and/or sell copies of the Software, and to
  * permit persons to whom the Software is furnished to do so, subject to
  * the following conditions:
  * 
  * The above copyright notice and this permission notice (including the
  * next paragraph) shall be included in all copies or substantial portions
  * of the Software.
  * 
  * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
  * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT.
  * IN NO EVENT SHALL INTEL AND/OR ITS SUPPLIERS BE LIABLE FOR
  * ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
  * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
  * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
  */
 /*
  * Video Acceleration (VA) API Specification
  *
  * Rev. 0.30
  * <jonathan.bian@intel.com>
  *
  * Revision History:
  * rev 0.10 (12/10/2006 Jonathan Bian) - Initial draft
  * rev 0.11 (12/15/2006 Jonathan Bian) - Fixed some errors
  * rev 0.12 (02/05/2007 Jonathan Bian) - Added VC-1 data structures for slice level decode
  * rev 0.13 (02/28/2007 Jonathan Bian) - Added GetDisplay()
  * rev 0.14 (04/13/2007 Jonathan Bian) - Fixed MPEG-2 PictureParameter structure, cleaned up a few funcs.
  * rev 0.15 (04/20/2007 Jonathan Bian) - Overhauled buffer management
  * rev 0.16 (05/02/2007 Jonathan Bian) - Added error codes and fixed some issues with configuration
  * rev 0.17 (05/07/2007 Jonathan Bian) - Added H.264/AVC data structures for slice level decode.
  * rev 0.18 (05/14/2007 Jonathan Bian) - Added data structures for MPEG-4 slice level decode 
  *                                       and MPEG-2 motion compensation.
  * rev 0.19 (08/06/2007 Jonathan Bian) - Removed extra type for bitplane data.
  * rev 0.20 (08/08/2007 Jonathan Bian) - Added missing fields to VC-1 PictureParameter structure.
  * rev 0.21 (08/20/2007 Jonathan Bian) - Added image and subpicture support.
  * rev 0.22 (08/27/2007 Jonathan Bian) - Added support for chroma-keying and global alpha.
  * rev 0.23 (09/11/2007 Jonathan Bian) - Fixed some issues with images and subpictures.
  * rev 0.24 (09/18/2007 Jonathan Bian) - Added display attributes.
  * rev 0.25 (10/18/2007 Jonathan Bian) - Changed to use IDs only for some types.
  * rev 0.26 (11/07/2007 Waldo Bastian) - Change vaCreateBuffer semantics
  * rev 0.27 (11/19/2007 Matt Sottek)   - Added DeriveImage
  * rev 0.28 (12/06/2007 Jonathan Bian) - Added new versions of PutImage and AssociateSubpicture 
  *                                       to enable scaling
  * rev 0.29 (02/07/2008 Jonathan Bian) - VC1 parameter fixes,
  *                                       added VA_STATUS_ERROR_RESOLUTION_NOT_SUPPORTED
  * rev 0.30 (03/01/2009 Jonathan Bian) - Added encoding support for H.264 BP and MPEG-4 SP and fixes
  *                                       for ISO C conformance.
  * rev 0.31 (09/02/2009 Gwenole Beauchesne) - VC-1/H264 fields change for VDPAU and XvBA backend
  *                                       Application needs to relink with the new library.
  *
  * rev 0.31.1 (03/29/2009)              - Data structure for JPEG encode
  * rev 0.31.2 (01/13/2011 Anthony Pabon)- Added a flag to indicate Subpicture coordinates are screen
  *                                        screen relative rather than source video relative.
  * rev 0.32.0 (01/13/2011 Xiang Haihao) - Add profile into VAPictureParameterBufferVC1
  *                                        update VAAPI to 0.32.0
  *
  * Acknowledgements:
  *  Some concepts borrowed from XvMC and XvImage.
  *  Waldo Bastian (Intel), Matt Sottek (Intel),  Austin Yuan (Intel), and Gwenole Beauchesne (SDS)
  *  contributed to various aspects of the API.
  */
 
 #ifndef _VA_H_
 #define _VA_H_
 
 #include <stddef.h>
 #include <stdint.h>
 #include <va/va_version.h>
 
 #ifdef __cplusplus
 extern "C" {
 #endif
 
 #if defined(__GNUC__) && !defined(__COVERITY__)
 #define va_deprecated __attribute__((deprecated))
 #if __GNUC__ >= 6
 #define va_deprecated_enum va_deprecated
 #else
 #define va_deprecated_enum
 #endif
 #else
 #define va_deprecated
 #define va_deprecated_enum
 #endif
 
 typedef void* VADisplay;        /* window system dependent */
 
 typedef int VAStatus;   
 #define VA_STATUS_SUCCESS                       0x00000000
 #define VA_STATUS_ERROR_OPERATION_FAILED        0x00000001
 #define VA_STATUS_ERROR_ALLOCATION_FAILED       0x00000002
 #define VA_STATUS_ERROR_INVALID_DISPLAY         0x00000003
 #define VA_STATUS_ERROR_INVALID_CONFIG          0x00000004
 #define VA_STATUS_ERROR_INVALID_CONTEXT         0x00000005
 #define VA_STATUS_ERROR_INVALID_SURFACE         0x00000006
 #define VA_STATUS_ERROR_INVALID_BUFFER          0x00000007
 #define VA_STATUS_ERROR_INVALID_IMAGE           0x00000008
 #define VA_STATUS_ERROR_INVALID_SUBPICTURE      0x00000009
 #define VA_STATUS_ERROR_ATTR_NOT_SUPPORTED      0x0000000a
 #define VA_STATUS_ERROR_MAX_NUM_EXCEEDED        0x0000000b
 #define VA_STATUS_ERROR_UNSUPPORTED_PROFILE     0x0000000c
 #define VA_STATUS_ERROR_UNSUPPORTED_ENTRYPOINT  0x0000000d
 #define VA_STATUS_ERROR_UNSUPPORTED_RT_FORMAT   0x0000000e
 #define VA_STATUS_ERROR_UNSUPPORTED_BUFFERTYPE  0x0000000f
 #define VA_STATUS_ERROR_SURFACE_BUSY            0x00000010
 #define VA_STATUS_ERROR_FLAG_NOT_SUPPORTED      0x00000011
 #define VA_STATUS_ERROR_INVALID_PARAMETER       0x00000012
 #define VA_STATUS_ERROR_RESOLUTION_NOT_SUPPORTED 0x00000013
 #define VA_STATUS_ERROR_UNIMPLEMENTED           0x00000014
 #define VA_STATUS_ERROR_SURFACE_IN_DISPLAYING   0x00000015
 #define VA_STATUS_ERROR_INVALID_IMAGE_FORMAT    0x00000016
 #define VA_STATUS_ERROR_DECODING_ERROR          0x00000017
 #define VA_STATUS_ERROR_ENCODING_ERROR          0x00000018
 
 #define VA_STATUS_ERROR_INVALID_VALUE           0x00000019
 
 #define VA_STATUS_ERROR_UNSUPPORTED_FILTER      0x00000020
 
 #define VA_STATUS_ERROR_INVALID_FILTER_CHAIN    0x00000021
 
 #define VA_STATUS_ERROR_HW_BUSY                 0x00000022
 
 #define VA_STATUS_ERROR_UNSUPPORTED_MEMORY_TYPE 0x00000024
 
 #define VA_STATUS_ERROR_NOT_ENOUGH_BUFFER       0x00000025
 
 #define VA_STATUS_ERROR_TIMEDOUT                0x00000026
 #define VA_STATUS_ERROR_UNKNOWN                 0xFFFFFFFF
 
 #define VA_FRAME_PICTURE        0x00000000 
 #define VA_TOP_FIELD            0x00000001
 #define VA_BOTTOM_FIELD         0x00000002
 #define VA_TOP_FIELD_FIRST      0x00000004
 #define VA_BOTTOM_FIELD_FIRST   0x00000008
 
 #define VA_ENABLE_BLEND         0x00000004 /* video area blend with the constant color */ 
     
 #define VA_CLEAR_DRAWABLE       0x00000008
 
 #define VA_SRC_COLOR_MASK       0x000000f0
 #define VA_SRC_BT601            0x00000010
 #define VA_SRC_BT709            0x00000020
 #define VA_SRC_SMPTE_240        0x00000040
 
 #define VA_FILTER_SCALING_DEFAULT       0x00000000
 #define VA_FILTER_SCALING_FAST          0x00000100
 #define VA_FILTER_SCALING_HQ            0x00000200
 #define VA_FILTER_SCALING_NL_ANAMORPHIC 0x00000300
 #define VA_FILTER_SCALING_MASK          0x00000f00
 
 #define VA_FILTER_INTERPOLATION_DEFAULT                    0x00000000
 #define VA_FILTER_INTERPOLATION_NEAREST_NEIGHBOR           0x00001000
 #define VA_FILTER_INTERPOLATION_BILINEAR                   0x00002000
 #define VA_FILTER_INTERPOLATION_ADVANCED                   0x00003000
 #define VA_FILTER_INTERPOLATION_MASK                       0x0000f000
 
 #define VA_PADDING_LOW          4
 #define VA_PADDING_MEDIUM       8
 #define VA_PADDING_HIGH         16
 #define VA_PADDING_LARGE        32
 
 #define VA_EXEC_SYNC              0x0
 
 #define VA_EXEC_ASYNC             0x1
 
 #define VA_EXEC_MODE_DEFAULT      0x0
 #define VA_EXEC_MODE_POWER_SAVING 0x1
 #define VA_EXEC_MODE_PERFORMANCE  0x2
 
 /* Values used to describe device features. */
 #define VA_FEATURE_NOT_SUPPORTED  0
 
 #define VA_FEATURE_SUPPORTED      1
 
 #define VA_FEATURE_REQUIRED       2
 
 const char *vaErrorStr(VAStatus error_status);
 
 typedef struct _VARectangle
 {
     int16_t x;
     int16_t y;
     uint16_t width;
     uint16_t height;
 } VARectangle;
 
 typedef struct _VAMotionVector {
     int16_t  mv0[2];  /* past reference */
     int16_t  mv1[2];  /* future reference */
 } VAMotionVector;
 
 typedef void (*VAMessageCallback)(void *user_context, const char *message);
 
 VAMessageCallback vaSetErrorCallback(VADisplay dpy, VAMessageCallback callback, void *user_context);
 
 VAMessageCallback vaSetInfoCallback(VADisplay dpy, VAMessageCallback callback, void *user_context);
 
 typedef void* VANativeDisplay;  /* window system dependent */
 
 int vaDisplayIsValid(VADisplay dpy);
 
 VAStatus vaSetDriverName(VADisplay dpy,
                          char *driver_name
 );
 
 VAStatus vaInitialize (
     VADisplay dpy,
     int *major_version,  /* out */
     int *minor_version   /* out */
 );
 
 VAStatus vaTerminate (
     VADisplay dpy
 );
 
 const char *vaQueryVendorString (
     VADisplay dpy
 );
 
 typedef int (*VAPrivFunc)(void);
 
 VAPrivFunc vaGetLibFunc (
     VADisplay dpy,
     const char *func
 );
 
 typedef enum
 {
     VAProfileNone                       = -1,
     VAProfileMPEG2Simple                = 0,
     VAProfileMPEG2Main                  = 1,
     VAProfileMPEG4Simple                = 2,
     VAProfileMPEG4AdvancedSimple        = 3,
     VAProfileMPEG4Main                  = 4,
     VAProfileH264Baseline va_deprecated_enum = 5,
     VAProfileH264Main                   = 6,
     VAProfileH264High                   = 7,
     VAProfileVC1Simple                  = 8,
     VAProfileVC1Main                    = 9,
     VAProfileVC1Advanced                = 10,
     VAProfileH263Baseline               = 11,
     VAProfileJPEGBaseline               = 12,
     VAProfileH264ConstrainedBaseline    = 13,
     VAProfileVP8Version0_3              = 14,
     VAProfileH264MultiviewHigh          = 15,
     VAProfileH264StereoHigh             = 16,
     VAProfileHEVCMain                   = 17,
     VAProfileHEVCMain10                 = 18,
     VAProfileVP9Profile0                = 19,
     VAProfileVP9Profile1                = 20,
     VAProfileVP9Profile2                = 21,
     VAProfileVP9Profile3                = 22,
     VAProfileHEVCMain12                 = 23,
     VAProfileHEVCMain422_10             = 24,
     VAProfileHEVCMain422_12             = 25,
     VAProfileHEVCMain444                = 26,
     VAProfileHEVCMain444_10             = 27,
     VAProfileHEVCMain444_12             = 28,
     VAProfileHEVCSccMain                = 29,
     VAProfileHEVCSccMain10              = 30,
     VAProfileHEVCSccMain444             = 31,
     VAProfileAV1Profile0                = 32,
     VAProfileAV1Profile1                = 33,
     VAProfileHEVCSccMain444_10          = 34,
     VAProfileProtected                  = 35
 } VAProfile;
 
 typedef enum
 {
     VAEntrypointVLD             = 1,
     VAEntrypointIZZ             = 2,
     VAEntrypointIDCT            = 3,
     VAEntrypointMoComp          = 4,
     VAEntrypointDeblocking      = 5,
     VAEntrypointEncSlice        = 6,    /* slice level encode */
     VAEntrypointEncPicture      = 7,    /* pictuer encode, JPEG, etc */
     /*
      * For an implementation that supports a low power/high performance variant
      * for slice level encode, it can choose to expose the
      * VAEntrypointEncSliceLP entrypoint. Certain encoding tools may not be
      * available with this entrypoint (e.g. interlace, MBAFF) and the
      * application can query the encoding configuration attributes to find
      * out more details if this entrypoint is supported.
      */
     VAEntrypointEncSliceLP      = 8,
     VAEntrypointVideoProc       = 10,   
     VAEntrypointFEI         = 11,
     VAEntrypointStats       = 12,
     VAEntrypointProtectedTEEComm       = 13,
     VAEntrypointProtectedContent       = 14,
 } VAEntrypoint;
 
 typedef enum
 {
     VAConfigAttribRTFormat              = 0,
     VAConfigAttribSpatialResidual       = 1,
     VAConfigAttribSpatialClipping       = 2,
     VAConfigAttribIntraResidual         = 3,
     VAConfigAttribEncryption            = 4,
     VAConfigAttribRateControl           = 5,
 
     VAConfigAttribDecSliceMode          = 6,
     VAConfigAttribDecJPEG             = 7,
     VAConfigAttribDecProcessing         = 8,
     VAConfigAttribEncPackedHeaders      = 10,
     VAConfigAttribEncInterlaced         = 11,
     VAConfigAttribEncMaxRefFrames       = 13,
     VAConfigAttribEncMaxSlices          = 14,
     VAConfigAttribEncSliceStructure     = 15,
     VAConfigAttribEncMacroblockInfo     = 16,
     VAConfigAttribMaxPictureWidth     = 18,
     VAConfigAttribMaxPictureHeight    = 19,
     VAConfigAttribEncJPEG             = 20,
     VAConfigAttribEncQualityRange     = 21,
     VAConfigAttribEncQuantization     = 22,
     VAConfigAttribEncIntraRefresh     = 23,
     VAConfigAttribEncSkipFrame        = 24,
     VAConfigAttribEncROI              = 25,
     VAConfigAttribEncRateControlExt   = 26,
     VAConfigAttribProcessingRate    = 27,
      VAConfigAttribEncDirtyRect       = 28,
      VAConfigAttribEncParallelRateControl   = 29,
      VAConfigAttribEncDynamicScaling        = 30,
      VAConfigAttribFrameSizeToleranceSupport = 31,
      VAConfigAttribFEIFunctionType     = 32,
     VAConfigAttribFEIMVPredictors     = 33,
     VAConfigAttribStats               = 34,
      VAConfigAttribEncTileSupport        = 35,
     VAConfigAttribCustomRoundingControl = 36,
     VAConfigAttribQPBlockSize            = 37,
     VAConfigAttribMaxFrameSize           = 38,
     VAConfigAttribPredictionDirection   = 39,
     VAConfigAttribMultipleFrame         = 40,
     VAConfigAttribContextPriority       = 41,
     VAConfigAttribDecAV1Features    = 42,
     VAConfigAttribTEEType               = 43,
     VAConfigAttribTEETypeClient         = 44,
     VAConfigAttribProtectedContentCipherAlgorithm = 45,
     VAConfigAttribProtectedContentCipherBlockSize = 46,
     VAConfigAttribProtectedContentCipherMode = 47,
     VAConfigAttribProtectedContentCipherSampleType = 48,
     VAConfigAttribProtectedContentUsage = 49,
 
     VAConfigAttribEncHEVCFeatures       = 50,
     VAConfigAttribEncHEVCBlockSizes     = 51,
     VAConfigAttribTypeMax
 } VAConfigAttribType;
 
 typedef struct _VAConfigAttrib {
     VAConfigAttribType type;
     uint32_t value; /* OR'd flags (bits) for this attribute */
 } VAConfigAttrib;
 
 /* Attribute values for VAConfigAttribRTFormat. */
 
 #define VA_RT_FORMAT_YUV420     0x00000001      
 #define VA_RT_FORMAT_YUV422     0x00000002      
 #define VA_RT_FORMAT_YUV444     0x00000004      
 #define VA_RT_FORMAT_YUV411     0x00000008      
 #define VA_RT_FORMAT_YUV400     0x00000010      
 #define VA_RT_FORMAT_YUV420_10  0x00000100      
 #define VA_RT_FORMAT_YUV422_10  0x00000200      
 #define VA_RT_FORMAT_YUV444_10  0x00000400      
 #define VA_RT_FORMAT_YUV420_12  0x00001000      
 #define VA_RT_FORMAT_YUV422_12  0x00002000      
 #define VA_RT_FORMAT_YUV444_12  0x00004000      
 
 #define VA_RT_FORMAT_RGB16      0x00010000      
 #define VA_RT_FORMAT_RGB32      0x00020000      
 #define VA_RT_FORMAT_RGBP       0x00100000      
 #define VA_RT_FORMAT_RGB32_10   0x00200000      
 
 #define VA_RT_FORMAT_PROTECTED  0x80000000
 
 #define VA_RT_FORMAT_RGB32_10BPP        VA_RT_FORMAT_RGB32_10   
 #define VA_RT_FORMAT_YUV420_10BPP       VA_RT_FORMAT_YUV420_10  
 
 
 #define VA_RC_NONE                      0x00000001
 
 #define VA_RC_CBR                       0x00000002
 
 #define VA_RC_VBR                       0x00000004
 
 #define VA_RC_VCM                       0x00000008
 
 #define VA_RC_CQP                       0x00000010
 
 #define VA_RC_VBR_CONSTRAINED           0x00000020
 
 #define VA_RC_ICQ                       0x00000040
 
 #define VA_RC_MB                        0x00000080
 
 #define VA_RC_CFS                       0x00000100
 
 #define VA_RC_PARALLEL                  0x00000200
 
 #define VA_RC_QVBR                      0x00000400
 
 #define VA_RC_AVBR                      0x00000800
 
 #define VA_RC_TCBRC                     0x00001000
 
 #define VA_DEC_SLICE_MODE_NORMAL       0x00000001
 
 #define VA_DEC_SLICE_MODE_BASE         0x00000002
 
 typedef union _VAConfigAttribValDecJPEG {
     struct {
     uint32_t rotation : 4;
     uint32_t reserved : 28;
     } bits;
     uint32_t value;
 } VAConfigAttribValDecJPEG;
 #define VA_DEC_PROCESSING_NONE     0x00000000
 
 #define VA_DEC_PROCESSING          0x00000001
 
 #define VA_ENC_PACKED_HEADER_NONE       0x00000000
 
 #define VA_ENC_PACKED_HEADER_SEQUENCE   0x00000001
 
 #define VA_ENC_PACKED_HEADER_PICTURE    0x00000002
 
 #define VA_ENC_PACKED_HEADER_SLICE      0x00000004
 
 #define VA_ENC_PACKED_HEADER_MISC       0x00000008
 
 #define VA_ENC_PACKED_HEADER_RAW_DATA   0x00000010
 
 #define VA_ENC_INTERLACED_NONE          0x00000000
 
 #define VA_ENC_INTERLACED_FRAME         0x00000001
 
 #define VA_ENC_INTERLACED_FIELD         0x00000002
 
 #define VA_ENC_INTERLACED_MBAFF         0x00000004
 
 #define VA_ENC_INTERLACED_PAFF          0x00000008
 
 #define VA_ENC_SLICE_STRUCTURE_POWER_OF_TWO_ROWS        0x00000001
 
 #define VA_ENC_SLICE_STRUCTURE_ARBITRARY_MACROBLOCKS    0x00000002
 
 #define VA_ENC_SLICE_STRUCTURE_EQUAL_ROWS               0x00000004
 
 #define VA_ENC_SLICE_STRUCTURE_MAX_SLICE_SIZE           0x00000008
 
 #define VA_ENC_SLICE_STRUCTURE_ARBITRARY_ROWS           0x00000010
 
 #define VA_ENC_SLICE_STRUCTURE_EQUAL_MULTI_ROWS         0x00000020
 
 typedef union _VAConfigAttribValMaxFrameSize {
     struct {
         uint32_t max_frame_size : 1;
         uint32_t multiple_pass  : 1;
         uint32_t reserved       :30;
     } bits;
     uint32_t value;
 } VAConfigAttribValMaxFrameSize;
 
 typedef union _VAConfigAttribValEncJPEG {
     struct {
         uint32_t arithmatic_coding_mode : 1;
         uint32_t progressive_dct_mode : 1;
         uint32_t non_interleaved_mode : 1;
         uint32_t differential_mode : 1;
         uint32_t max_num_components : 3;
         uint32_t max_num_scans : 4;
         uint32_t max_num_huffman_tables : 3;
         uint32_t max_num_quantization_tables : 3;
     } bits;
     uint32_t value;
 } VAConfigAttribValEncJPEG;
 
 #define VA_ENC_QUANTIZATION_NONE                        0x00000000
 
 #define VA_ENC_QUANTIZATION_TRELLIS_SUPPORTED           0x00000001
 
 #define VA_PREDICTION_DIRECTION_PREVIOUS                0x00000001
 
 #define VA_PREDICTION_DIRECTION_FUTURE                  0x00000002
 
 #define VA_PREDICTION_DIRECTION_BI_NOT_EMPTY            0x00000004
 
 #define VA_ENC_INTRA_REFRESH_NONE                       0x00000000
 
 #define VA_ENC_INTRA_REFRESH_ROLLING_COLUMN             0x00000001
 
 #define VA_ENC_INTRA_REFRESH_ROLLING_ROW                0x00000002
 
 #define VA_ENC_INTRA_REFRESH_ADAPTIVE                   0x00000010
 
 #define VA_ENC_INTRA_REFRESH_CYCLIC                     0x00000020
 
 #define VA_ENC_INTRA_REFRESH_P_FRAME                    0x00010000
 
 #define VA_ENC_INTRA_REFRESH_B_FRAME                    0x00020000
 
 #define VA_ENC_INTRA_REFRESH_MULTI_REF                  0x00040000
 
 typedef union _VAConfigAttribValEncROI {
     struct {
         uint32_t num_roi_regions                : 8;
         uint32_t roi_rc_priority_support        : 1;
         uint32_t roi_rc_qp_delta_support    : 1;
         uint32_t reserved                   : 22;
      } bits;
      uint32_t value;
 } VAConfigAttribValEncROI;
 
 typedef union _VAConfigAttribValEncRateControlExt {
     struct {
         uint32_t max_num_temporal_layers_minus1      : 8;
 
         uint32_t temporal_layer_bitrate_control_flag : 1;
         uint32_t reserved                            : 23;
     } bits;
     uint32_t value;
 } VAConfigAttribValEncRateControlExt;
 
 typedef union _VAConfigAttribValMultipleFrame {
     struct {
         uint32_t max_num_concurrent_frames      : 8;
         uint32_t mixed_quality_level            : 1;
         uint32_t reserved                       : 23;
     } bits;
     uint32_t value;
 }VAConfigAttribValMultipleFrame;
 
 typedef union _VAConfigAttribValContextPriority{
     struct{
         uint32_t priority     :16;
         uint32_t reserved     :16;
     }bits;
     uint32_t value;
 }VAConfigAttribValContextPriority;
 
 #define VA_PC_CIPHER_AES                    0x00000001
 
 #define VA_PC_BLOCK_SIZE_128                0x00000001
 
 #define VA_PC_BLOCK_SIZE_192                0x00000002
 
 #define VA_PC_BLOCK_SIZE_256                0x00000004
 
 #define VA_PC_CIPHER_MODE_ECB               0x00000001
 
 #define VA_PC_CIPHER_MODE_CBC               0x00000002
 
 #define VA_PC_CIPHER_MODE_CTR               0x00000004
 
 #define VA_PC_SAMPLE_TYPE_FULLSAMPLE        0x00000001
 
 #define VA_PC_SAMPLE_TYPE_SUBSAMPLE         0x00000002
 
 #define VA_PC_USAGE_DEFAULT                 0x00000000
 
 #define VA_PC_USAGE_WIDEVINE                0x00000001
 
 #define VA_PROCESSING_RATE_NONE                       0x00000000
 
 #define VA_PROCESSING_RATE_ENCODE                     0x00000001
 
 #define VA_PROCESSING_RATE_DECODE                     0x00000002
 
 #define VA_ATTRIB_NOT_SUPPORTED 0x80000000
 
 int vaMaxNumProfiles (
     VADisplay dpy
 );
 
 int vaMaxNumEntrypoints (
     VADisplay dpy
 );
 
 int vaMaxNumConfigAttributes (
     VADisplay dpy
 );
 
 VAStatus vaQueryConfigProfiles (
     VADisplay dpy,
     VAProfile *profile_list,    /* out */
     int *num_profiles           /* out */
 );
 
 VAStatus vaQueryConfigEntrypoints (
     VADisplay dpy,
     VAProfile profile,
     VAEntrypoint *entrypoint_list,      /* out */
     int *num_entrypoints                /* out */
 );
 
 VAStatus vaGetConfigAttributes (
     VADisplay dpy,
     VAProfile profile,
     VAEntrypoint entrypoint,
     VAConfigAttrib *attrib_list, /* in/out */
     int num_attribs
 );
 
 typedef unsigned int VAGenericID;
 
 typedef VAGenericID VAConfigID;
 
 VAStatus vaCreateConfig (
     VADisplay dpy,
     VAProfile profile, 
     VAEntrypoint entrypoint, 
     VAConfigAttrib *attrib_list,
     int num_attribs,
     VAConfigID *config_id /* out */
 );
 
 VAStatus vaDestroyConfig (
     VADisplay dpy,
     VAConfigID config_id
 );
 
 VAStatus vaQueryConfigAttributes (
     VADisplay dpy,
     VAConfigID config_id, 
     VAProfile *profile,         /* out */
     VAEntrypoint *entrypoint,   /* out */
     VAConfigAttrib *attrib_list,/* out */
     int *num_attribs            /* out */
 );
 
 
 typedef VAGenericID VAContextID;
 
 typedef VAGenericID VASurfaceID;
 
 #define VA_INVALID_ID           0xffffffff
 #define VA_INVALID_SURFACE      VA_INVALID_ID
 
 typedef enum  {
     VAGenericValueTypeInteger = 1,      
     VAGenericValueTypeFloat,            
     VAGenericValueTypePointer,          
     VAGenericValueTypeFunc              
 } VAGenericValueType;
 
 typedef void (*VAGenericFunc)(void);
 
 typedef struct _VAGenericValue {
     VAGenericValueType  type;
     union {
         int32_t             i;
         float           f;
         void           *p;
         VAGenericFunc   fn;
     }                   value;
 } VAGenericValue;
 
 #define VA_SURFACE_ATTRIB_NOT_SUPPORTED 0x00000000
 
 #define VA_SURFACE_ATTRIB_GETTABLE      0x00000001
 
 #define VA_SURFACE_ATTRIB_SETTABLE      0x00000002
 
 typedef enum {
     VASurfaceAttribNone = 0,
     VASurfaceAttribPixelFormat,
     VASurfaceAttribMinWidth,
     VASurfaceAttribMaxWidth,
     VASurfaceAttribMinHeight,
     VASurfaceAttribMaxHeight,
     VASurfaceAttribMemoryType,
     VASurfaceAttribExternalBufferDescriptor,
     VASurfaceAttribUsageHint,
     VASurfaceAttribDRMFormatModifiers,
     VASurfaceAttribCount
 } VASurfaceAttribType;
 
 typedef struct _VASurfaceAttrib {
     VASurfaceAttribType type;
     uint32_t        flags;
     VAGenericValue      value;
 } VASurfaceAttrib;
 
 #define VA_SURFACE_ATTRIB_MEM_TYPE_VA                   0x00000001
 
 #define VA_SURFACE_ATTRIB_MEM_TYPE_V4L2                 0x00000002
 
 #define VA_SURFACE_ATTRIB_MEM_TYPE_USER_PTR             0x00000004
 
 typedef struct _VASurfaceAttribExternalBuffers {
     uint32_t pixel_format;
     uint32_t width;
     uint32_t height;
     uint32_t data_size;
     uint32_t num_planes;
     uint32_t pitches[4];
     uint32_t offsets[4];
     uintptr_t *buffers;
     uint32_t num_buffers;
     uint32_t flags;
     void *private_data;
 } VASurfaceAttribExternalBuffers;
 
 #define VA_SURFACE_EXTBUF_DESC_ENABLE_TILING    0x00000001
 
 #define VA_SURFACE_EXTBUF_DESC_CACHED           0x00000002
 
 #define VA_SURFACE_EXTBUF_DESC_UNCACHED         0x00000004
 
 #define VA_SURFACE_EXTBUF_DESC_WC               0x00000008
 
 #define VA_SURFACE_EXTBUF_DESC_PROTECTED        0x80000000
 
 #define VA_SURFACE_ATTRIB_USAGE_HINT_GENERIC    0x00000000
 
 #define VA_SURFACE_ATTRIB_USAGE_HINT_DECODER    0x00000001
 
 #define VA_SURFACE_ATTRIB_USAGE_HINT_ENCODER    0x00000002
 
 #define VA_SURFACE_ATTRIB_USAGE_HINT_VPP_READ   0x00000004
 
 #define VA_SURFACE_ATTRIB_USAGE_HINT_VPP_WRITE  0x00000008
 
 #define VA_SURFACE_ATTRIB_USAGE_HINT_DISPLAY    0x00000010
 
 #define VA_SURFACE_ATTRIB_USAGE_HINT_EXPORT     0x00000020
 
 VAStatus
 vaQuerySurfaceAttributes(
     VADisplay           dpy,
     VAConfigID          config,
     VASurfaceAttrib    *attrib_list,
     unsigned int       *num_attribs
 );
 
 VAStatus
 vaCreateSurfaces(
     VADisplay           dpy,
     unsigned int        format,
     unsigned int        width,
     unsigned int        height,
     VASurfaceID        *surfaces,
     unsigned int        num_surfaces,
     VASurfaceAttrib    *attrib_list,
     unsigned int        num_attribs
 );
     
 VAStatus vaDestroySurfaces (
     VADisplay dpy,
     VASurfaceID *surfaces,
     int num_surfaces
 );
 
 #define VA_PROGRESSIVE 0x1
 
 VAStatus vaCreateContext (
     VADisplay dpy,
     VAConfigID config_id,
     int picture_width,
     int picture_height,
     int flag,
     VASurfaceID *render_targets,
     int num_render_targets,
     VAContextID *context                /* out */
 );
 
 VAStatus vaDestroyContext (
     VADisplay dpy,
     VAContextID context
 );
 
 //Multi-frame context
 typedef VAGenericID VAMFContextID;
 VAStatus vaCreateMFContext (
     VADisplay dpy,
     VAMFContextID *mf_context    /* out */
 );
 
 VAStatus vaMFAddContext (
     VADisplay dpy,
     VAMFContextID mf_context,
     VAContextID context
 );
 
 VAStatus vaMFReleaseContext (
     VADisplay dpy,
     VAMFContextID mf_context,
     VAContextID context
 );
 
 typedef VAGenericID VABufferID;
 
 typedef enum
 {
     VAPictureParameterBufferType        = 0,
     VAIQMatrixBufferType                = 1,
     VABitPlaneBufferType                = 2,
     VASliceGroupMapBufferType           = 3,
     VASliceParameterBufferType          = 4,
     VASliceDataBufferType               = 5,
     VAMacroblockParameterBufferType     = 6,
     VAResidualDataBufferType            = 7,
     VADeblockingParameterBufferType     = 8,
     VAImageBufferType                   = 9,
     VAProtectedSliceDataBufferType      = 10,
     VAQMatrixBufferType                 = 11,
     VAHuffmanTableBufferType            = 12,
     VAProbabilityBufferType             = 13,
 
 /* Following are encode buffer types */
     VAEncCodedBufferType                = 21,
     VAEncSequenceParameterBufferType    = 22,
     VAEncPictureParameterBufferType     = 23,
     VAEncSliceParameterBufferType       = 24,
     VAEncPackedHeaderParameterBufferType = 25,
     VAEncPackedHeaderDataBufferType     = 26,
     VAEncMiscParameterBufferType        = 27,
     VAEncMacroblockParameterBufferType  = 28,
     VAEncMacroblockMapBufferType        = 29,
 
     VAEncQPBufferType                   = 30,
 /* Following are video processing buffer types */
     VAProcPipelineParameterBufferType   = 41,
     VAProcFilterParameterBufferType     = 42,
     VAEncFEIMVBufferType                = 43,
     VAEncFEIMBCodeBufferType            = 44,
     VAEncFEIDistortionBufferType        = 45,
     VAEncFEIMBControlBufferType         = 46,
     VAEncFEIMVPredictorBufferType       = 47,
     VAStatsStatisticsParameterBufferType = 48,
     VAStatsStatisticsBufferType         = 49,
     VAStatsStatisticsBottomFieldBufferType = 50,
     VAStatsMVBufferType                 = 51,
     VAStatsMVPredictorBufferType        = 52,
     VAEncMacroblockDisableSkipMapBufferType = 53,
     VAEncFEICTBCmdBufferType            = 54,
     VAEncFEICURecordBufferType          = 55,
     VADecodeStreamoutBufferType             = 56,
 
     VASubsetsParameterBufferType        = 57,
     VAContextParameterUpdateBufferType  = 58,
     VAProtectedSessionExecuteBufferType = 59,
 
     VAEncryptionParameterBufferType = 60,
 
     VABufferTypeMax
 } VABufferType;
 
 typedef struct _VAContextParameterUpdateBuffer
 {
     union{
         struct {
             uint32_t context_priority_update :1;
             uint32_t reserved                :31;
         } bits;
         uint32_t value;
     }flags;
     VAConfigAttribValContextPriority context_priority;
     uint32_t reserved[VA_PADDING_MEDIUM];
 } VAContextParameterUpdateBuffer;
 
 #define VA_ENCRYPTION_TYPE_FULLSAMPLE_CTR       0x00000001  /* AES CTR fullsample */
 #define VA_ENCRYPTION_TYPE_FULLSAMPLE_CBC       0x00000002  /* AES CBC fullsample */
 #define VA_ENCRYPTION_TYPE_SUBSAMPLE_CTR        0x00000004  /* AES CTR fullsample */
 #define VA_ENCRYPTION_TYPE_SUBSAMPLE_CBC        0x00000008  /* AES CBC fullsample */
 
 typedef struct _VAEncryptionSegmentInfo {
   uint32_t segment_start_offset;
   uint32_t segment_length;
   uint32_t partial_aes_block_size;
   uint32_t init_byte_length;
   uint8_t aes_cbc_iv_or_ctr[64];
   uint32_t va_reserved[VA_PADDING_MEDIUM];
 } VAEncryptionSegmentInfo;
 
 typedef struct _VAEncryptionParameters {
   uint32_t encryption_type;
   uint32_t num_segments;
   VAEncryptionSegmentInfo *segment_info;
   uint32_t status_report_index;
   uint32_t size_of_length;
   uint8_t wrapped_decrypt_blob[64];
   uint8_t wrapped_encrypt_blob[64];
   uint32_t key_blob_size;
   uint32_t blocks_stripe_encrypted;
   uint32_t blocks_stripe_clear;
   uint32_t va_reserved[VA_PADDING_MEDIUM];
 } VAEncryptionParameters;
 
 typedef struct _VAProcessingRateParameterEnc {
     uint8_t         level_idc;
     uint8_t         reserved[3];
     uint32_t        quality_level;
     uint32_t        intra_period;
     uint32_t        ip_period;
 } VAProcessingRateParameterEnc;
 
 typedef struct _VAProcessingRateParameterDec {
     uint8_t         level_idc;
     uint8_t         reserved0[3];
     uint32_t        reserved;
 } VAProcessingRateParameterDec;
 
 typedef struct _VAProcessingRateParameter {
     union {
         VAProcessingRateParameterEnc proc_buf_enc;
         VAProcessingRateParameterDec proc_buf_dec;
     };
 } VAProcessingRateParameter;
 
 VAStatus
 vaQueryProcessingRate(
     VADisplay           dpy,
     VAConfigID          config,
     VAProcessingRateParameter *proc_buf,
     unsigned int       *processing_rate
 );
 
 typedef enum
 {
     VAEncMiscParameterTypeFrameRate     = 0,
     VAEncMiscParameterTypeRateControl   = 1,
     VAEncMiscParameterTypeMaxSliceSize  = 2,
     VAEncMiscParameterTypeAIR           = 3,
     VAEncMiscParameterTypeMaxFrameSize  = 4,
     VAEncMiscParameterTypeHRD           = 5,
     VAEncMiscParameterTypeQualityLevel  = 6,
     VAEncMiscParameterTypeRIR           = 7,
     VAEncMiscParameterTypeQuantization  = 8,
     VAEncMiscParameterTypeSkipFrame     = 9,
     VAEncMiscParameterTypeROI           = 10,
     VAEncMiscParameterTypeMultiPassFrameSize       = 11,
     VAEncMiscParameterTypeTemporalLayerStructure   = 12,
     VAEncMiscParameterTypeDirtyRect      = 13,
     VAEncMiscParameterTypeParallelBRC   = 14,
     VAEncMiscParameterTypeSubMbPartPel = 15,
     VAEncMiscParameterTypeEncQuality = 16,
     VAEncMiscParameterTypeCustomRoundingControl = 17,
     VAEncMiscParameterTypeFEIFrameControl = 18,
     VAEncMiscParameterTypeExtensionData = 19
 } VAEncMiscParameterType;
 
 typedef enum {
     VAEncPackedHeaderSequence   = 1,
     VAEncPackedHeaderPicture    = 2,
     VAEncPackedHeaderSlice      = 3,
     VAEncPackedHeaderRawData    = 4,
     VAEncPackedHeaderMiscMask va_deprecated_enum  = 0x80000000,
 } VAEncPackedHeaderType;
 
 typedef struct _VAEncPackedHeaderParameterBuffer {
     uint32_t                type;
     uint32_t                bit_length;
     uint8_t               has_emulation_bytes;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAEncPackedHeaderParameterBuffer;
 
 typedef struct _VAEncMiscParameterBuffer
 {
     VAEncMiscParameterType type;
     uint32_t data[];
 } VAEncMiscParameterBuffer;
 
 typedef struct _VAEncMiscParameterTemporalLayerStructure
 {
     uint32_t number_of_layers;
     uint32_t periodicity;
     uint32_t layer_id[32];
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAEncMiscParameterTemporalLayerStructure;
 
 
 typedef struct _VAEncMiscParameterRateControl
 {
     uint32_t bits_per_second;
     uint32_t target_percentage;
     uint32_t window_size;
     uint32_t initial_qp;
     uint32_t min_qp;
     uint32_t basic_unit_size;
     union
     {
         struct
         {
             uint32_t reset : 1;
             uint32_t disable_frame_skip : 1;
             uint32_t disable_bit_stuffing : 1;
             uint32_t mb_rate_control : 4;
             uint32_t temporal_id : 8;
             uint32_t cfs_I_frames : 1;
             uint32_t enable_parallel_brc    : 1;
             uint32_t enable_dynamic_scaling : 1;
             uint32_t frame_tolerance_mode   : 2;
             uint32_t reserved               : 12;
         } bits;
         uint32_t value;
     } rc_flags;
     uint32_t ICQ_quality_factor;
     uint32_t max_qp;
     uint32_t quality_factor;
     uint32_t target_frame_size;
     uint32_t va_reserved[VA_PADDING_LOW];
 } VAEncMiscParameterRateControl;
 
 typedef struct _VAEncMiscParameterFrameRate
 {
     uint32_t framerate;
     union
     {
         struct
         {
             uint32_t temporal_id : 8;
             uint32_t reserved : 24;
          } bits;
          uint32_t value;
      } framerate_flags;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAEncMiscParameterFrameRate;
 
 typedef struct _VAEncMiscParameterMaxSliceSize
 {
     uint32_t max_slice_size;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAEncMiscParameterMaxSliceSize;
 
 typedef struct _VAEncMiscParameterAIR
 {
     uint32_t air_num_mbs;
     uint32_t air_threshold;
     uint32_t air_auto; /* if set to 1 then hardware auto-tune the AIR threshold */
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAEncMiscParameterAIR;
 
 /*
  * \brief Rolling intra refresh data structure for encoding.
  */
 typedef struct _VAEncMiscParameterRIR
 {
     union
     {
         struct
         {
             /* \brief enable RIR in column */
             uint32_t enable_rir_column : 1;
             /* \brief enable RIR in row */
             uint32_t enable_rir_row : 1;
             uint32_t reserved : 30;
         } bits;
         uint32_t value;
     } rir_flags;
     uint16_t intra_insertion_location;
     uint16_t intra_insert_size;
     uint8_t  qp_delta_for_inserted_intra;
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAEncMiscParameterRIR;
 
 typedef struct _VAEncMiscParameterHRD
 {
     uint32_t initial_buffer_fullness;
     uint32_t buffer_size;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAEncMiscParameterHRD;
 
 typedef struct _VAEncMiscParameterBufferMaxFrameSize {
     va_deprecated VAEncMiscParameterType      type;
     uint32_t                max_frame_size;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAEncMiscParameterBufferMaxFrameSize;
 
 typedef struct _VAEncMiscParameterBufferMultiPassFrameSize {
     va_deprecated VAEncMiscParameterType      type;
     uint32_t                max_frame_size;
     uint32_t                reserved;
     uint8_t                 num_passes;
     uint8_t                *delta_qp;
 
     unsigned long           va_reserved[VA_PADDING_LOW];
 } VAEncMiscParameterBufferMultiPassFrameSize;
 
 typedef struct _VAEncMiscParameterBufferQualityLevel {
     uint32_t                quality_level;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAEncMiscParameterBufferQualityLevel;
 
 typedef struct _VAEncMiscParameterQuantization
 {
     union
     {
     /* if no flags is set then quantization is determined by the driver */
         struct
         {
             /* \brief disable trellis for all frames/fields */
             uint32_t disable_trellis : 1;
             /* \brief enable trellis for I frames/fields */
             uint32_t enable_trellis_I : 1;
             /* \brief enable trellis for P frames/fields */
             uint32_t enable_trellis_P : 1;
             /* \brief enable trellis for B frames/fields */
             uint32_t enable_trellis_B : 1;
             uint32_t reserved : 28;
         } bits;
         uint32_t value;
     } quantization_flags;
     uint32_t va_reserved;
 } VAEncMiscParameterQuantization;
 
 typedef struct _VAEncMiscParameterSkipFrame {
     uint8_t               skip_frame_flag;
     uint8_t               num_skip_frames;
     uint32_t                size_skip_frames;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAEncMiscParameterSkipFrame;
 
 typedef struct _VAEncROI
 {
         VARectangle     roi_rectangle;
         int8_t            roi_value;
 } VAEncROI;
 
 typedef struct _VAEncMiscParameterBufferROI {
     uint32_t        num_roi;
 
     int8_t                max_delta_qp;
     int8_t                min_delta_qp;
 
     VAEncROI            *roi;
     union {
         struct {
             uint32_t  roi_value_is_qp_delta    : 1;
             uint32_t  reserved                 : 31;
         } bits;
         uint32_t value;
     } roi_flags;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAEncMiscParameterBufferROI;
 /*
  * \brief Dirty rectangle data structure for encoding.
  *
  * The encoding dirty rect can be set through VAEncMiscParameterBufferDirtyRect, if the
  * implementation supports dirty rect input. The rect set through this structure is applicable
  * only to the current frame or field, so must be sent every frame or field to be applied.
  * The number of supported rects can be queried through the VAConfigAttribEncDirtyRect.  The
  * encoder will use the rect information to know those rectangle areas have changed while the
  * areas not covered by dirty rect rectangles are assumed to have not changed compared to the
  * previous picture.  The encoder may do some internal optimizations.
  */
 typedef struct _VAEncMiscParameterBufferDirtyRect
 {
     uint32_t    num_roi_rectangle;
 
      VARectangle    *roi_rectangle;
 } VAEncMiscParameterBufferDirtyRect;
 
 typedef struct _VAEncMiscParameterParallelRateControl {
     uint32_t num_layers;
     uint32_t *num_b_in_gop;
 } VAEncMiscParameterParallelRateControl;
 
 typedef struct _VAEncMiscParameterEncQuality
 {
     union
     {
         struct
         {
             uint32_t useRawPicForRef                    : 1;
             uint32_t skipCheckDisable                   : 1;
             uint32_t FTQOverride                        : 1;
             uint32_t FTQEnable                          : 1;
             uint32_t FTQSkipThresholdLUTInput           : 1;
             uint32_t NonFTQSkipThresholdLUTInput        : 1;
             uint32_t ReservedBit                        : 1;
             uint32_t directBiasAdjustmentEnable         : 1;
             uint32_t globalMotionBiasAdjustmentEnable   : 1;
             uint32_t HMEMVCostScalingFactor             : 2;
             uint32_t HMEDisable                         : 1;
             uint32_t SuperHMEDisable                    : 1;
             uint32_t UltraHMEDisable                    : 1;
             uint32_t PanicModeDisable                   : 1;
             uint32_t ForceRepartitionCheck              : 2;
 
         };
         uint32_t encControls;
     };
 
     uint8_t FTQSkipThresholdLUT[52];
     uint16_t NonFTQSkipThresholdLUT[52];
 
     uint32_t reserved[VA_PADDING_HIGH];  // Reserved for future use.
 
 } VAEncMiscParameterEncQuality;
 
 typedef struct _VAEncMiscParameterCustomRoundingControl
 {
     union {
         struct {
             uint32_t    enable_custom_rouding_intra     : 1 ;
 
             uint32_t    rounding_offset_intra           : 7;
 
             uint32_t    enable_custom_rounding_inter    : 1 ;
 
             uint32_t    rounding_offset_inter           : 7;
 
            /* Reserved */
             uint32_t    reserved                        :16;
         }  bits;
         uint32_t    value;
     }   rounding_offset_setting;
 } VAEncMiscParameterCustomRoundingControl;
 
 #define VA_SLICE_DATA_FLAG_ALL          0x00    /* whole slice is in the buffer */
 #define VA_SLICE_DATA_FLAG_BEGIN        0x01    /* The beginning of the slice is in the buffer but the end if not */
 #define VA_SLICE_DATA_FLAG_MIDDLE       0x02    /* Neither beginning nor end of the slice is in the buffer */
 #define VA_SLICE_DATA_FLAG_END          0x04    /* end of the slice is in the buffer */
 
 /* Codec-independent Slice Parameter Buffer base */
 typedef struct _VASliceParameterBufferBase
 {
     uint32_t slice_data_size;   /* number of bytes in the slice data buffer for this slice */
     uint32_t slice_data_offset; /* the offset to the first byte of slice data */
     uint32_t slice_data_flag;   /* see VA_SLICE_DATA_FLAG_XXX definitions */
 } VASliceParameterBufferBase;
 
 /**********************************
  * JPEG common  data structures
  **********************************/
 typedef struct _VAHuffmanTableBufferJPEGBaseline {
     uint8_t       load_huffman_table[2];
     struct {
         uint8_t   num_dc_codes[16];
         uint8_t   dc_values[12];
         uint8_t   num_ac_codes[16];
         uint8_t   ac_values[162];
         uint8_t   pad[2];
     }                   huffman_table[2];
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAHuffmanTableBufferJPEGBaseline;
 
 /****************************
  * MPEG-2 data structures
  ****************************/
  
 /* MPEG-2 Picture Parameter Buffer */
 /* 
  * For each frame or field, and before any slice data, a single
  * picture parameter buffer must be send.
  */
 typedef struct _VAPictureParameterBufferMPEG2
 {
     uint16_t horizontal_size;
     uint16_t vertical_size;
     VASurfaceID forward_reference_picture;
     VASurfaceID backward_reference_picture;
     /* meanings of the following fields are the same as in the standard */
     int32_t picture_coding_type;
     int32_t f_code; /* pack all four fcode into this */
     union {
         struct {
             uint32_t intra_dc_precision         : 2; 
             uint32_t picture_structure          : 2; 
             uint32_t top_field_first            : 1; 
             uint32_t frame_pred_frame_dct               : 1; 
             uint32_t concealment_motion_vectors : 1;
             uint32_t q_scale_type                       : 1;
             uint32_t intra_vlc_format           : 1;
             uint32_t alternate_scan                     : 1;
             uint32_t repeat_first_field         : 1;
             uint32_t progressive_frame          : 1;
             uint32_t is_first_field                     : 1; /* indicate whether the current field
                                                               * is the first field for field picture
                                                               */
         } bits;
         uint32_t value;
     } picture_coding_extension;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAPictureParameterBufferMPEG2;
 
 typedef struct _VAIQMatrixBufferMPEG2
 {
     int32_t load_intra_quantiser_matrix;
     int32_t load_non_intra_quantiser_matrix;
     int32_t load_chroma_intra_quantiser_matrix;
     int32_t load_chroma_non_intra_quantiser_matrix;
     uint8_t intra_quantiser_matrix[64];
     uint8_t non_intra_quantiser_matrix[64];
     uint8_t chroma_intra_quantiser_matrix[64];
     uint8_t chroma_non_intra_quantiser_matrix[64];
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAIQMatrixBufferMPEG2;
 
 typedef struct _VASliceParameterBufferMPEG2
 {
     uint32_t slice_data_size;/* number of bytes in the slice data buffer for this slice */
     uint32_t slice_data_offset;/* the offset to the first byte of slice data */
     uint32_t slice_data_flag; /* see VA_SLICE_DATA_FLAG_XXX defintions */
     uint32_t macroblock_offset;/* the offset to the first bit of MB from the first byte of slice data */
     uint32_t slice_horizontal_position;
     uint32_t slice_vertical_position;
     int32_t quantiser_scale_code;
     int32_t intra_slice_flag;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VASliceParameterBufferMPEG2;
 
 typedef struct _VAMacroblockParameterBufferMPEG2
 {
     uint16_t macroblock_address;
     /* 
      * macroblock_address (in raster scan order)
      * top-left: 0
      * bottom-right: picture-height-in-mb*picture-width-in-mb - 1
      */
     uint8_t macroblock_type;  /* see definition below */
     union {
         struct {
             uint32_t frame_motion_type          : 2; 
             uint32_t field_motion_type          : 2; 
             uint32_t dct_type                   : 1; 
         } bits;
         uint32_t value;
     } macroblock_modes;
     uint8_t motion_vertical_field_select; 
     /* 
      * motion_vertical_field_select:
      * see section 6.3.17.2 in the spec
      * only the lower 4 bits are used
      * bit 0: first vector forward
      * bit 1: first vector backward
      * bit 2: second vector forward
      * bit 3: second vector backward
      */
     int16_t PMV[2][2][2]; /* see Table 7-7 in the spec */
     uint16_t coded_block_pattern;
     /* 
      * The bitplanes for coded_block_pattern are described 
      * in Figure 6.10-12 in the spec
      */
      
     /* Number of skipped macroblocks after this macroblock */
     uint16_t num_skipped_macroblocks;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAMacroblockParameterBufferMPEG2;
 
 /* 
  * OR'd flags for macroblock_type (section 6.3.17.1 in the spec)
  */
 #define VA_MB_TYPE_MOTION_FORWARD       0x02
 #define VA_MB_TYPE_MOTION_BACKWARD      0x04
 #define VA_MB_TYPE_MOTION_PATTERN       0x08
 #define VA_MB_TYPE_MOTION_INTRA         0x10
 
 /****************************
  * MPEG-4 Part 2 data structures
  ****************************/
  
 /* MPEG-4 Picture Parameter Buffer */
 /* 
  * For each frame or field, and before any slice data, a single
  * picture parameter buffer must be send.
  */
 typedef struct _VAPictureParameterBufferMPEG4
 {
     uint16_t vop_width;
     uint16_t vop_height;
     VASurfaceID forward_reference_picture;
     VASurfaceID backward_reference_picture;
     union {
         struct {
             uint32_t short_video_header         : 1; 
             uint32_t chroma_format                      : 2; 
             uint32_t interlaced                 : 1; 
             uint32_t obmc_disable                       : 1; 
             uint32_t sprite_enable                      : 2; 
             uint32_t sprite_warping_accuracy    : 2; 
             uint32_t quant_type                 : 1; 
             uint32_t quarter_sample                     : 1; 
             uint32_t data_partitioned           : 1; 
             uint32_t reversible_vlc                     : 1; 
             uint32_t resync_marker_disable              : 1; 
         } bits;
         uint32_t value;
     } vol_fields;
     uint8_t no_of_sprite_warping_points;
     int16_t sprite_trajectory_du[3];
     int16_t sprite_trajectory_dv[3];
     uint8_t quant_precision;
     union {
         struct {
             uint32_t vop_coding_type            : 2; 
             uint32_t backward_reference_vop_coding_type : 2; 
             uint32_t vop_rounding_type          : 1; 
             uint32_t intra_dc_vlc_thr           : 3; 
             uint32_t top_field_first            : 1; 
             uint32_t alternate_vertical_scan_flag       : 1; 
         } bits;
         uint32_t value;
     } vop_fields;
     uint8_t vop_fcode_forward;
     uint8_t vop_fcode_backward;
     uint16_t vop_time_increment_resolution;
     /* short header related */
     uint8_t num_gobs_in_vop;
     uint8_t num_macroblocks_in_gob;
     /* for direct mode prediction */
     int16_t TRB;
     int16_t TRD;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAPictureParameterBufferMPEG4;
 
 typedef struct _VAIQMatrixBufferMPEG4
 {
     int32_t load_intra_quant_mat;
     int32_t load_non_intra_quant_mat;
     uint8_t intra_quant_mat[64];
     uint8_t non_intra_quant_mat[64];
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAIQMatrixBufferMPEG4;
 
 typedef struct _VASliceParameterBufferMPEG4
 {
     uint32_t slice_data_size;/* number of bytes in the slice data buffer for this slice */
     uint32_t slice_data_offset;/* the offset to the first byte of slice data */
     uint32_t slice_data_flag; /* see VA_SLICE_DATA_FLAG_XXX defintions */
     uint32_t macroblock_offset;/* the offset to the first bit of MB from the first byte of slice data */
     uint32_t macroblock_number;
     int32_t quant_scale;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VASliceParameterBufferMPEG4;
 
 typedef enum   /* see 7.1.1.32 */
 {
     VAMvMode1Mv                        = 0,
     VAMvMode1MvHalfPel                 = 1,
     VAMvMode1MvHalfPelBilinear         = 2,
     VAMvModeMixedMv                    = 3,
     VAMvModeIntensityCompensation      = 4 
 } VAMvModeVC1;
 
 /* 
  * For each picture, and before any slice data, a picture parameter
  * buffer must be send. Multiple picture parameter buffers may be
  * sent for a single picture. In that case picture parameters will
  * apply to all slice data that follow it until a new picture
  * parameter buffer is sent.
  *
  * Notes:
  *   pic_quantizer_type should be set to the applicable quantizer
  *   type as defined by QUANTIZER (J.1.19) and either
  *   PQUANTIZER (7.1.1.8) or PQINDEX (7.1.1.6)
  */
 typedef struct _VAPictureParameterBufferVC1
 {
     VASurfaceID forward_reference_picture;
     VASurfaceID backward_reference_picture;
     /* if out-of-loop post-processing is done on the render
        target, then we need to keep the in-loop decoded 
        picture as a reference picture */
     VASurfaceID inloop_decoded_picture;
 
     /* sequence layer for AP or meta data for SP and MP */
     union {
         struct {
             uint32_t pulldown   : 1; /* SEQUENCE_LAYER::PULLDOWN */
             uint32_t interlace  : 1; /* SEQUENCE_LAYER::INTERLACE */
             uint32_t tfcntrflag : 1; /* SEQUENCE_LAYER::TFCNTRFLAG */
             uint32_t finterpflag        : 1; /* SEQUENCE_LAYER::FINTERPFLAG */
             uint32_t psf                : 1; /* SEQUENCE_LAYER::PSF */
             uint32_t multires   : 1; /* METADATA::MULTIRES */
             uint32_t overlap    : 1; /* METADATA::OVERLAP */
             uint32_t syncmarker : 1; /* METADATA::SYNCMARKER */
             uint32_t rangered   : 1; /* METADATA::RANGERED */
             uint32_t max_b_frames       : 3; /* METADATA::MAXBFRAMES */
             uint32_t profile    : 2; /* SEQUENCE_LAYER::PROFILE or The MSB of METADATA::PROFILE */
         } bits;
         uint32_t value;
     } sequence_fields;
 
     uint16_t coded_width;               /* ENTRY_POINT_LAYER::CODED_WIDTH */
     uint16_t coded_height;      /* ENTRY_POINT_LAYER::CODED_HEIGHT */
     union {
         struct {
             uint32_t broken_link        : 1; /* ENTRY_POINT_LAYER::BROKEN_LINK */
             uint32_t closed_entry       : 1; /* ENTRY_POINT_LAYER::CLOSED_ENTRY */
             uint32_t panscan_flag       : 1; /* ENTRY_POINT_LAYER::PANSCAN_FLAG */
             uint32_t loopfilter : 1; /* ENTRY_POINT_LAYER::LOOPFILTER */
         } bits;
         uint32_t value;
     } entrypoint_fields;
     uint8_t conditional_overlap_flag; /* ENTRY_POINT_LAYER::CONDOVER */
     uint8_t fast_uvmc_flag;     /* ENTRY_POINT_LAYER::FASTUVMC */
     union {
         struct {
             uint32_t luma_flag  : 1; /* ENTRY_POINT_LAYER::RANGE_MAPY_FLAG */
             uint32_t luma               : 3; /* ENTRY_POINT_LAYER::RANGE_MAPY */
             uint32_t chroma_flag        : 1; /* ENTRY_POINT_LAYER::RANGE_MAPUV_FLAG */
             uint32_t chroma             : 3; /* ENTRY_POINT_LAYER::RANGE_MAPUV */
         } bits;
         uint32_t value;
     } range_mapping_fields;
 
     uint8_t b_picture_fraction; /* Index for PICTURE_LAYER::BFRACTION value in Table 40 (7.1.1.14) */
     uint8_t cbp_table;          /* PICTURE_LAYER::CBPTAB/ICBPTAB */
     uint8_t mb_mode_table;      /* PICTURE_LAYER::MBMODETAB */
     uint8_t range_reduction_frame;/* PICTURE_LAYER::RANGEREDFRM */
     uint8_t rounding_control;   /* PICTURE_LAYER::RNDCTRL */
     uint8_t post_processing;    /* PICTURE_LAYER::POSTPROC */
     uint8_t picture_resolution_index;   /* PICTURE_LAYER::RESPIC */
     uint8_t luma_scale;         /* PICTURE_LAYER::LUMSCALE */
     uint8_t luma_shift;         /* PICTURE_LAYER::LUMSHIFT */
 
     union {
         struct {
             uint32_t picture_type               : 3; /* PICTURE_LAYER::PTYPE */
             uint32_t frame_coding_mode  : 3; /* PICTURE_LAYER::FCM */
             uint32_t top_field_first    : 1; /* PICTURE_LAYER::TFF */
             uint32_t is_first_field             : 1; /* set to 1 if it is the first field */
             uint32_t intensity_compensation     : 1; /* PICTURE_LAYER::INTCOMP */
         } bits;
         uint32_t value;
     } picture_fields;
     union {
         struct {
             uint32_t mv_type_mb : 1;    /* PICTURE::MVTYPEMB */
             uint32_t direct_mb  : 1;    /* PICTURE::DIRECTMB */
             uint32_t skip_mb    : 1;    /* PICTURE::SKIPMB */
             uint32_t field_tx   : 1;    /* PICTURE::FIELDTX */
             uint32_t forward_mb : 1;    /* PICTURE::FORWARDMB */
             uint32_t ac_pred    : 1;    /* PICTURE::ACPRED */
             uint32_t overflags  : 1;    /* PICTURE::OVERFLAGS */
         } flags;
         uint32_t value;
     } raw_coding;
     union {
         struct {
             uint32_t bp_mv_type_mb   : 1;    /* PICTURE::MVTYPEMB */
             uint32_t bp_direct_mb    : 1;    /* PICTURE::DIRECTMB */
             uint32_t bp_skip_mb      : 1;    /* PICTURE::SKIPMB */  
             uint32_t bp_field_tx     : 1;    /* PICTURE::FIELDTX */ 
             uint32_t bp_forward_mb   : 1;    /* PICTURE::FORWARDMB */
             uint32_t bp_ac_pred      : 1;    /* PICTURE::ACPRED */   
             uint32_t bp_overflags    : 1;    /* PICTURE::OVERFLAGS */
         } flags;
         uint32_t value;
     } bitplane_present; /* signal what bitplane is being passed via the bitplane buffer */
     union {
         struct {
             uint32_t reference_distance_flag : 1;/* PICTURE_LAYER::REFDIST_FLAG */
             uint32_t reference_distance : 5;/* PICTURE_LAYER::REFDIST */
             uint32_t num_reference_pictures: 1;/* PICTURE_LAYER::NUMREF */
             uint32_t reference_field_pic_indicator      : 1;/* PICTURE_LAYER::REFFIELD */
         } bits;
         uint32_t value;
     } reference_fields;
     union {
         struct {
             uint32_t mv_mode            : 3; /* PICTURE_LAYER::MVMODE */
             uint32_t mv_mode2           : 3; /* PICTURE_LAYER::MVMODE2 */
             uint32_t mv_table           : 3; /* PICTURE_LAYER::MVTAB/IMVTAB */
             uint32_t two_mv_block_pattern_table: 2; /* PICTURE_LAYER::2MVBPTAB */
             uint32_t four_mv_switch             : 1; /* PICTURE_LAYER::4MVSWITCH */
             uint32_t four_mv_block_pattern_table : 2; /* PICTURE_LAYER::4MVBPTAB */
             uint32_t extended_mv_flag   : 1; /* ENTRY_POINT_LAYER::EXTENDED_MV */
             uint32_t extended_mv_range  : 2; /* PICTURE_LAYER::MVRANGE */
             uint32_t extended_dmv_flag  : 1; /* ENTRY_POINT_LAYER::EXTENDED_DMV */
             uint32_t extended_dmv_range : 2; /* PICTURE_LAYER::DMVRANGE */
         } bits;
         uint32_t value;
     } mv_fields;
     union {
         struct {
             uint32_t dquant     : 2;    /* ENTRY_POINT_LAYER::DQUANT */
             uint32_t quantizer     : 2;         /* ENTRY_POINT_LAYER::QUANTIZER */
             uint32_t half_qp    : 1;    /* PICTURE_LAYER::HALFQP */
             uint32_t pic_quantizer_scale : 5;/* PICTURE_LAYER::PQUANT */
             uint32_t pic_quantizer_type : 1;/* PICTURE_LAYER::PQUANTIZER */
             uint32_t dq_frame   : 1;    /* VOPDQUANT::DQUANTFRM */
             uint32_t dq_profile : 2;    /* VOPDQUANT::DQPROFILE */
             uint32_t dq_sb_edge : 2;    /* VOPDQUANT::DQSBEDGE */
             uint32_t dq_db_edge         : 2;    /* VOPDQUANT::DQDBEDGE */
             uint32_t dq_binary_level : 1;       /* VOPDQUANT::DQBILEVEL */
             uint32_t alt_pic_quantizer : 5;/* VOPDQUANT::ALTPQUANT */
         } bits;
         uint32_t value;
     } pic_quantizer_fields;
     union {
         struct {
             uint32_t variable_sized_transform_flag      : 1;/* ENTRY_POINT_LAYER::VSTRANSFORM */
             uint32_t mb_level_transform_type_flag       : 1;/* PICTURE_LAYER::TTMBF */
             uint32_t frame_level_transform_type : 2;/* PICTURE_LAYER::TTFRM */
             uint32_t transform_ac_codingset_idx1        : 2;/* PICTURE_LAYER::TRANSACFRM */
             uint32_t transform_ac_codingset_idx2        : 2;/* PICTURE_LAYER::TRANSACFRM2 */
             uint32_t intra_transform_dc_table   : 1;/* PICTURE_LAYER::TRANSDCTAB */
         } bits;
         uint32_t value;
     } transform_fields;
 
     uint8_t luma_scale2;                  /* PICTURE_LAYER::LUMSCALE2 */
     uint8_t luma_shift2;                  /* PICTURE_LAYER::LUMSHIFT2 */
     uint8_t intensity_compensation_field; /* Index for PICTURE_LAYER::INTCOMPFIELD value in Table 109 (9.1.1.48) */
 
     uint32_t                va_reserved[VA_PADDING_MEDIUM - 1];
 } VAPictureParameterBufferVC1;
 
 /* VC-1 Slice Parameter Buffer */
 typedef struct _VASliceParameterBufferVC1
 {
     uint32_t slice_data_size;/* number of bytes in the slice data buffer for this slice */
     uint32_t slice_data_offset;/* the offset to the first byte of slice data */
     uint32_t slice_data_flag; /* see VA_SLICE_DATA_FLAG_XXX defintions */
     uint32_t macroblock_offset;/* the offset to the first bit of MB from the first byte of slice data */
     uint32_t slice_vertical_position;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VASliceParameterBufferVC1;
 
 /* VC-1 Slice Data Buffer */
 /* 
 This is simplely a buffer containing raw bit-stream bytes 
 */
 
 /****************************
  * H.264/AVC data structures
  ****************************/
 
 typedef struct _VAPictureH264
 {
     VASurfaceID picture_id;
     uint32_t frame_idx;
     uint32_t flags;
     int32_t TopFieldOrderCnt;
     int32_t BottomFieldOrderCnt;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAPictureH264;
 /* flags in VAPictureH264 could be OR of the following */
 #define VA_PICTURE_H264_INVALID                 0x00000001
 #define VA_PICTURE_H264_TOP_FIELD               0x00000002
 #define VA_PICTURE_H264_BOTTOM_FIELD            0x00000004
 #define VA_PICTURE_H264_SHORT_TERM_REFERENCE    0x00000008
 #define VA_PICTURE_H264_LONG_TERM_REFERENCE     0x00000010
 
 /* 
  * For each picture, and before any slice data, a single
  * picture parameter buffer must be send.
  */
 typedef struct _VAPictureParameterBufferH264
 {
     VAPictureH264 CurrPic;
     VAPictureH264 ReferenceFrames[16];  /* in DPB */
     uint16_t picture_width_in_mbs_minus1;
     uint16_t picture_height_in_mbs_minus1;
     uint8_t bit_depth_luma_minus8;
     uint8_t bit_depth_chroma_minus8;
     uint8_t num_ref_frames;
     union {
         struct {
             uint32_t chroma_format_idc                  : 2; 
             uint32_t residual_colour_transform_flag             : 1; /* Renamed to separate_colour_plane_flag in newer standard versions. */
             uint32_t gaps_in_frame_num_value_allowed_flag       : 1; 
             uint32_t frame_mbs_only_flag                        : 1; 
             uint32_t mb_adaptive_frame_field_flag               : 1; 
             uint32_t direct_8x8_inference_flag          : 1; 
             uint32_t MinLumaBiPredSize8x8                       : 1; /* see A.3.3.2 */
             uint32_t log2_max_frame_num_minus4          : 4;
             uint32_t pic_order_cnt_type                 : 2;
             uint32_t log2_max_pic_order_cnt_lsb_minus4  : 4;
             uint32_t delta_pic_order_always_zero_flag   : 1;
         } bits;
         uint32_t value;
     } seq_fields;
     // FMO is not supported.
     va_deprecated uint8_t num_slice_groups_minus1;
     va_deprecated uint8_t slice_group_map_type;
     va_deprecated uint16_t slice_group_change_rate_minus1;
     int8_t pic_init_qp_minus26;
     int8_t pic_init_qs_minus26;
     int8_t chroma_qp_index_offset;
     int8_t second_chroma_qp_index_offset;
     union {
         struct {
             uint32_t entropy_coding_mode_flag   : 1;
             uint32_t weighted_pred_flag         : 1;
             uint32_t weighted_bipred_idc                : 2;
             uint32_t transform_8x8_mode_flag    : 1;
             uint32_t field_pic_flag                     : 1;
             uint32_t constrained_intra_pred_flag        : 1;
             uint32_t pic_order_present_flag                     : 1; /* Renamed to bottom_field_pic_order_in_frame_present_flag in newer standard versions. */
             uint32_t deblocking_filter_control_present_flag : 1;
             uint32_t redundant_pic_cnt_present_flag             : 1;
             uint32_t reference_pic_flag                 : 1; /* nal_ref_idc != 0 */
         } bits;
         uint32_t value;
     } pic_fields;
     uint16_t frame_num;
 
     uint32_t                va_reserved[VA_PADDING_MEDIUM];
 } VAPictureParameterBufferH264;
 
 typedef struct _VAIQMatrixBufferH264
 {
     uint8_t ScalingList4x4[6][16];
     uint8_t ScalingList8x8[2][64];
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAIQMatrixBufferH264;
 
 typedef struct _VASliceParameterBufferH264
 {
     uint32_t slice_data_size;/* number of bytes in the slice data buffer for this slice */
     uint32_t slice_data_offset;
     uint32_t slice_data_flag; /* see VA_SLICE_DATA_FLAG_XXX defintions */
     uint16_t slice_data_bit_offset;
     uint16_t first_mb_in_slice;
     uint8_t slice_type;
     uint8_t direct_spatial_mv_pred_flag;
     uint8_t num_ref_idx_l0_active_minus1;
     uint8_t num_ref_idx_l1_active_minus1;
     uint8_t cabac_init_idc;
     int8_t slice_qp_delta;
     uint8_t disable_deblocking_filter_idc;
     int8_t slice_alpha_c0_offset_div2;
     int8_t slice_beta_offset_div2;
     VAPictureH264 RefPicList0[32];      /* See 8.2.4.2 */
     VAPictureH264 RefPicList1[32];      /* See 8.2.4.2 */
     uint8_t luma_log2_weight_denom;
     uint8_t chroma_log2_weight_denom;
     uint8_t luma_weight_l0_flag;
     int16_t luma_weight_l0[32];
     int16_t luma_offset_l0[32];
     uint8_t chroma_weight_l0_flag;
     int16_t chroma_weight_l0[32][2];
     int16_t chroma_offset_l0[32][2];
     uint8_t luma_weight_l1_flag;
     int16_t luma_weight_l1[32];
     int16_t luma_offset_l1[32];
     uint8_t chroma_weight_l1_flag;
     int16_t chroma_weight_l1[32][2];
     int16_t chroma_offset_l1[32][2];
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VASliceParameterBufferH264;
 
 /****************************
  * Common encode data structures 
  ****************************/
 typedef enum
 {
     VAEncPictureTypeIntra               = 0,
     VAEncPictureTypePredictive          = 1,
     VAEncPictureTypeBidirectional       = 2,
 } VAEncPictureType;
 
 typedef struct _VAEncSliceParameterBuffer
 {
     uint32_t start_row_number;  /* starting MB row number for this slice */
     uint32_t slice_height;      /* slice height measured in MB */
     union {
         struct {
             uint32_t is_intra   : 1;
             uint32_t disable_deblocking_filter_idc : 2;
             uint32_t uses_long_term_ref         :1;
             uint32_t is_long_term_ref           :1;
         } bits;
         uint32_t value;
     } slice_flags;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAEncSliceParameterBuffer;
 
 
 /****************************
  * H.263 specific encode data structures
  ****************************/
 
 typedef struct _VAEncSequenceParameterBufferH263
 {
     uint32_t intra_period;
     uint32_t bits_per_second;
     uint32_t frame_rate;
     uint32_t initial_qp;
     uint32_t min_qp;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAEncSequenceParameterBufferH263;
 
 typedef struct _VAEncPictureParameterBufferH263
 {
     VASurfaceID reference_picture;
     VASurfaceID reconstructed_picture;
     VABufferID coded_buf;
     uint16_t picture_width;
     uint16_t picture_height;
     VAEncPictureType picture_type;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAEncPictureParameterBufferH263;
 
 /****************************
  * MPEG-4 specific encode data structures
  ****************************/
 
 typedef struct _VAEncSequenceParameterBufferMPEG4
 {
     uint8_t profile_and_level_indication;
     uint32_t intra_period;
     uint32_t video_object_layer_width;
     uint32_t video_object_layer_height;
     uint32_t vop_time_increment_resolution;
     uint32_t fixed_vop_rate;
     uint32_t fixed_vop_time_increment;
     uint32_t bits_per_second;
     uint32_t frame_rate;
     uint32_t initial_qp;
     uint32_t min_qp;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAEncSequenceParameterBufferMPEG4;
 
 typedef struct _VAEncPictureParameterBufferMPEG4
 {
     VASurfaceID reference_picture;
     VASurfaceID reconstructed_picture;
     VABufferID coded_buf;
     uint16_t picture_width;
     uint16_t picture_height;
     uint32_t modulo_time_base; /* number of 1s */
     uint32_t vop_time_increment;
     VAEncPictureType picture_type;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAEncPictureParameterBufferMPEG4;
 
 
 
 VAStatus vaCreateBuffer (
     VADisplay dpy,
     VAContextID context,
     VABufferType type,  /* in */
     unsigned int size,  /* in */
     unsigned int num_elements, /* in */
     void *data,         /* in */
     VABufferID *buf_id  /* out */
 );
 
 VAStatus vaCreateBuffer2(
     VADisplay dpy,
     VAContextID context,
     VABufferType type,
     unsigned int width,
     unsigned int height,
     unsigned int *unit_size,
     unsigned int *pitch,
     VABufferID *buf_id
 );
 
 VAStatus vaBufferSetNumElements (
     VADisplay dpy,
     VABufferID buf_id,  /* in */
     unsigned int num_elements /* in */
 );
 
 
 /* 
  * FICTURE_AVE_QP(bit7-0): The average Qp value used during this frame
  * LARGE_SLICE(bit8):At least one slice in the current frame was large
  *              enough for the encoder to attempt to limit its size.
  * SLICE_OVERFLOW(bit9): At least one slice in the current frame has
  *              exceeded the maximum slice size specified.
  * BITRATE_OVERFLOW(bit10): The peak bitrate was exceeded for this frame.
  * BITRATE_HIGH(bit11): The frame size got within the safety margin of the maximum size (VCM only)
  * AIR_MB_OVER_THRESHOLD: the number of MBs adapted to Intra MB
  */
 #define VA_CODED_BUF_STATUS_PICTURE_AVE_QP_MASK         0xff
 #define VA_CODED_BUF_STATUS_LARGE_SLICE_MASK            0x100
 #define VA_CODED_BUF_STATUS_SLICE_OVERFLOW_MASK         0x200
 #define VA_CODED_BUF_STATUS_BITRATE_OVERFLOW            0x400
 #define VA_CODED_BUF_STATUS_BITRATE_HIGH                0x800
 
 #define VA_CODED_BUF_STATUS_FRAME_SIZE_OVERFLOW         0x1000
 
 #define VA_CODED_BUF_STATUS_BAD_BITSTREAM               0x8000
 #define VA_CODED_BUF_STATUS_AIR_MB_OVER_THRESHOLD       0xff0000
 
 #define VA_CODED_BUF_STATUS_NUMBER_PASSES_MASK          0xf000000
 
 #define VA_CODED_BUF_STATUS_SINGLE_NALU                 0x10000000      
 
 typedef  struct _VACodedBufferSegment  {
     uint32_t        size;
     uint32_t        bit_offset;
     uint32_t        status;
     uint32_t        reserved;
     void               *buf;
     void               *next;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VACodedBufferSegment;
      
 VAStatus vaMapBuffer (
     VADisplay dpy,
     VABufferID buf_id,  /* in */
     void **pbuf         /* out */
 );
 
 VAStatus vaUnmapBuffer (
     VADisplay dpy,
     VABufferID buf_id   /* in */
 );
 
 VAStatus vaDestroyBuffer (
     VADisplay dpy,
     VABufferID buffer_id
 );
 
 typedef struct {
     uintptr_t           handle;
     uint32_t            type;
     uint32_t            mem_type;
     size_t              mem_size;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VABufferInfo;
 
 VAStatus
 vaAcquireBufferHandle(VADisplay dpy, VABufferID buf_id, VABufferInfo *buf_info);
 
 VAStatus
 vaReleaseBufferHandle(VADisplay dpy, VABufferID buf_id);
 
 #define VA_EXPORT_SURFACE_READ_ONLY        0x0001
 
 #define VA_EXPORT_SURFACE_WRITE_ONLY       0x0002
 
 #define VA_EXPORT_SURFACE_READ_WRITE       0x0003
 
 #define VA_EXPORT_SURFACE_SEPARATE_LAYERS  0x0004
 
 #define VA_EXPORT_SURFACE_COMPOSED_LAYERS  0x0008
 
 VAStatus vaExportSurfaceHandle(VADisplay dpy,
                                VASurfaceID surface_id,
                                uint32_t mem_type, uint32_t flags,
                                void *descriptor);
 
 VAStatus vaBeginPicture (
     VADisplay dpy,
     VAContextID context,
     VASurfaceID render_target
 );
 
 VAStatus vaRenderPicture (
     VADisplay dpy,
     VAContextID context,
     VABufferID *buffers,
     int num_buffers
 );
 
 VAStatus vaEndPicture (
     VADisplay dpy,
     VAContextID context
 );
 
 VAStatus vaMFSubmit (
     VADisplay dpy,
     VAMFContextID mf_context,
     VAContextID * contexts,
     int num_contexts
 );
 
 /*
 
 Synchronization 
 
 */
 
 VAStatus vaSyncSurface (
     VADisplay dpy,
     VASurfaceID render_target
 );
 
 #define VA_TIMEOUT_INFINITE 0xFFFFFFFFFFFFFFFF
 
 VAStatus vaSyncSurface2 (
     VADisplay dpy,
     VASurfaceID surface,
     uint64_t timeout_ns
 );
 
 typedef enum
 {
     VASurfaceRendering  = 1, /* Rendering in progress */ 
     VASurfaceDisplaying = 2, /* Displaying in progress (not safe to render into it) */ 
                              /* this status is useful if surface is used as the source */
                              /* of an overlay */
     VASurfaceReady      = 4, /* not being rendered or displayed */
     VASurfaceSkipped    = 8  /* Indicate a skipped frame during encode */
 } VASurfaceStatus;
 
 VAStatus vaQuerySurfaceStatus (
     VADisplay dpy,
     VASurfaceID render_target,
     VASurfaceStatus *status     /* out */
 );
 
 typedef enum
 {
     VADecodeSliceMissing            = 0,
     VADecodeMBError                 = 1,
 } VADecodeErrorType;
 
 typedef struct _VASurfaceDecodeMBErrors
 {
     int32_t status; /* 1 if hardware has returned detailed info below, -1 means this record is invalid */
     uint32_t start_mb; /* start mb address with errors */
     uint32_t end_mb;  /* end mb address with errors */
     VADecodeErrorType decode_error_type;
     uint32_t num_mb;   /* number of mbs with errors */
     uint32_t                va_reserved[VA_PADDING_LOW - 1];
 } VASurfaceDecodeMBErrors;
 
 VAStatus vaQuerySurfaceError(
     VADisplay dpy,
     VASurfaceID surface,
     VAStatus error_status,
     void **error_info
 );
 
 VAStatus vaSyncBuffer(
     VADisplay dpy,
     VABufferID buf_id,
     uint64_t timeout_ns
 );
 
 #define VA_FOURCC(ch0, ch1, ch2, ch3) \
     ((unsigned long)(unsigned char) (ch0) | ((unsigned long)(unsigned char) (ch1) << 8) | \
     ((unsigned long)(unsigned char) (ch2) << 16) | ((unsigned long)(unsigned char) (ch3) << 24 ))
 
 /* Pre-defined fourcc codes. */
 
 #define VA_FOURCC_NV12          0x3231564E
 
 #define VA_FOURCC_NV21          0x3132564E
 
 #define VA_FOURCC_AI44          0x34344149
 
 #define VA_FOURCC_RGBA          0x41424752
 
 #define VA_FOURCC_RGBX          0x58424752
 
 #define VA_FOURCC_BGRA          0x41524742
 
 #define VA_FOURCC_BGRX          0x58524742
 
 #define VA_FOURCC_ARGB          0x42475241
 
 #define VA_FOURCC_XRGB          0x42475258
 
 #define VA_FOURCC_ABGR          0x52474241
 
 #define VA_FOURCC_XBGR          0x52474258
 
 #define VA_FOURCC_UYVY          0x59565955
 
 #define VA_FOURCC_YUY2          0x32595559
 
 #define VA_FOURCC_AYUV          0x56555941
 
 #define VA_FOURCC_NV11          0x3131564e
 
 #define VA_FOURCC_YV12          0x32315659
 
 #define VA_FOURCC_P208          0x38303250
 
 #define VA_FOURCC_I420          0x30323449
 
 #define VA_FOURCC_YV24          0x34325659
 
 #define VA_FOURCC_YV32          0x32335659
 
 #define VA_FOURCC_Y800          0x30303859
 
 #define VA_FOURCC_IMC3          0x33434D49
 
 #define VA_FOURCC_411P          0x50313134
 
 #define VA_FOURCC_411R          0x52313134
 
 #define VA_FOURCC_422H          0x48323234
 
 #define VA_FOURCC_422V          0x56323234
 
 #define VA_FOURCC_444P          0x50343434
 
 #define VA_FOURCC_RGBP          0x50424752
 
 #define VA_FOURCC_BGRP          0x50524742
 
 #define VA_FOURCC_RGB565        0x36314752
 
 #define VA_FOURCC_BGR565        0x36314742
 
 #define VA_FOURCC_Y210          0x30313259
 
 #define VA_FOURCC_Y212          0x32313259
 
 #define VA_FOURCC_Y216          0x36313259
 
 #define VA_FOURCC_Y410          0x30313459
 
 #define VA_FOURCC_Y412          0x32313459
 
 #define VA_FOURCC_Y416          0x36313459
 
 #define VA_FOURCC_YV16          0x36315659
 
 #define VA_FOURCC_P010          0x30313050
 
 #define VA_FOURCC_P012          0x32313050
 
 #define VA_FOURCC_P016          0x36313050
 
 #define VA_FOURCC_I010          0x30313049
 
 #define VA_FOURCC_IYUV          0x56555949
 
 #define VA_FOURCC_A2R10G10B10   0x30335241 /* VA_FOURCC('A','R','3','0') */
 
 #define VA_FOURCC_A2B10G10R10   0x30334241 /* VA_FOURCC('A','B','3','0') */
 
 #define VA_FOURCC_X2R10G10B10   0x30335258 /* VA_FOURCC('X','R','3','0') */
 
 #define VA_FOURCC_X2B10G10R10   0x30334258 /* VA_FOURCC('X','B','3','0') */
 
 #define VA_FOURCC_Y8            0x20203859
 
 #define VA_FOURCC_Y16           0x20363159
 
 #define VA_FOURCC_VYUY          0x59555956
 
 #define VA_FOURCC_YVYU          0x55595659
 
 #define VA_FOURCC_ARGB64        0x34475241
 
 #define VA_FOURCC_ABGR64        0x34474241
 
 #define VA_FOURCC_XYUV          0x56555958
 
 /* byte order */
 #define VA_LSB_FIRST            1
 #define VA_MSB_FIRST            2
 
 typedef struct _VAImageFormat
 {
     uint32_t    fourcc;
     uint32_t    byte_order; /* VA_LSB_FIRST, VA_MSB_FIRST */
     uint32_t    bits_per_pixel;
     /* for RGB formats */
     uint32_t    depth; /* significant bits per pixel */
     uint32_t    red_mask;
     uint32_t    green_mask;
     uint32_t    blue_mask;
     uint32_t    alpha_mask;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAImageFormat;
 
 typedef VAGenericID VAImageID;
 
 typedef struct _VAImage
 {
     VAImageID           image_id; /* uniquely identify this image */
     VAImageFormat       format;
     VABufferID          buf;    /* image data buffer */
     /*
      * Image data will be stored in a buffer of type VAImageBufferType to facilitate
      * data store on the server side for optimal performance. The buffer will be 
      * created by the CreateImage function, and proper storage allocated based on the image
      * size and format. This buffer is managed by the library implementation, and 
      * accessed by the client through the buffer Map/Unmap functions.
      */
     uint16_t    width; 
     uint16_t    height;
     uint32_t    data_size;
     uint32_t    num_planes;     /* can not be greater than 3 */
     /* 
      * An array indicating the scanline pitch in bytes for each plane.
      * Each plane may have a different pitch. Maximum 3 planes for planar formats
      */
     uint32_t    pitches[3];
     /* 
      * An array indicating the byte offset from the beginning of the image data 
      * to the start of each plane.
      */
     uint32_t    offsets[3];
 
     /* The following fields are only needed for paletted formats */
     int32_t num_palette_entries;   /* set to zero for non-palette images */
     /* 
      * Each component is one byte and entry_bytes indicates the number of components in 
      * each entry (eg. 3 for YUV palette entries). set to zero for non-palette images   
      */
     int32_t entry_bytes; 
     /*
      * An array of ascii characters describing the order of the components within the bytes.
      * Only entry_bytes characters of the string are used.
      */
     int8_t component_order[4];
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAImage;
 
 int vaMaxNumImageFormats (
     VADisplay dpy
 );
 
 VAStatus vaQueryImageFormats (
     VADisplay dpy,
     VAImageFormat *format_list, /* out */
     int *num_formats            /* out */
 );
 
 VAStatus vaCreateImage (
     VADisplay dpy,
     VAImageFormat *format,
     int width,
     int height,
     VAImage *image      /* out */
 );
 
 VAStatus vaDestroyImage (
     VADisplay dpy,
     VAImageID image
 );
 
 VAStatus vaSetImagePalette (
     VADisplay dpy,
     VAImageID image,
     /* 
      * pointer to an array holding the palette data.  The size of the array is 
      * num_palette_entries * entry_bytes in size.  The order of the components 
      * in the palette is described by the component_order in VAImage struct    
      */
     unsigned char *palette 
 );
 
 VAStatus vaGetImage (
     VADisplay dpy,
     VASurfaceID surface,
     int x,      /* coordinates of the upper left source pixel */
     int y,
     unsigned int width, /* width and height of the region */
     unsigned int height,
     VAImageID image
 );
 
 VAStatus vaPutImage (
     VADisplay dpy,
     VASurfaceID surface,
     VAImageID image,
     int src_x,
     int src_y,
     unsigned int src_width,
     unsigned int src_height,
     int dest_x,
     int dest_y,
     unsigned int dest_width,
     unsigned int dest_height
 );
 
 VAStatus vaDeriveImage (
     VADisplay dpy,
     VASurfaceID surface,
     VAImage *image      /* out */
 );
 
 typedef VAGenericID VASubpictureID;
 
 int vaMaxNumSubpictureFormats (
     VADisplay dpy
 );
 
 #define VA_SUBPICTURE_CHROMA_KEYING                     0x0001
 #define VA_SUBPICTURE_GLOBAL_ALPHA                      0x0002
 #define VA_SUBPICTURE_DESTINATION_IS_SCREEN_COORD       0x0004
 
 VAStatus vaQuerySubpictureFormats (
     VADisplay dpy,
     VAImageFormat *format_list, /* out */
     unsigned int *flags,        /* out */
     unsigned int *num_formats   /* out */
 );
 
 VAStatus vaCreateSubpicture (
     VADisplay dpy,
     VAImageID image,
     VASubpictureID *subpicture  /* out */
 );
 
 VAStatus vaDestroySubpicture (
     VADisplay dpy,
     VASubpictureID subpicture
 );
 
 VAStatus vaSetSubpictureImage (
     VADisplay dpy,
     VASubpictureID subpicture,
     VAImageID image
 );
 
 VAStatus vaSetSubpictureChromakey (
     VADisplay dpy,
     VASubpictureID subpicture,
     unsigned int chromakey_min,
     unsigned int chromakey_max,
     unsigned int chromakey_mask
 );
 
 VAStatus vaSetSubpictureGlobalAlpha (
     VADisplay dpy,
     VASubpictureID subpicture,
     float global_alpha 
 );
 
 VAStatus vaAssociateSubpicture (
     VADisplay dpy,
     VASubpictureID subpicture,
     VASurfaceID *target_surfaces,
     int num_surfaces,
     int16_t src_x, /* upper left offset in subpicture */
     int16_t src_y,
     uint16_t src_width,
     uint16_t src_height,
     int16_t dest_x, /* upper left offset in surface */
     int16_t dest_y,
     uint16_t dest_width,
     uint16_t dest_height,
     /*
      * whether to enable chroma-keying, global-alpha, or screen relative mode
      * see VA_SUBPICTURE_XXX values
      */
     uint32_t flags
 );
 
 VAStatus vaDeassociateSubpicture (
     VADisplay dpy,
     VASubpictureID subpicture,
     VASurfaceID *target_surfaces,
     int num_surfaces
 );
 
 /* PowerVR IEP Lite attributes */
 typedef enum
 {
     VADISPLAYATTRIB_BLE_OFF              = 0x00,
     VADISPLAYATTRIB_BLE_LOW,
     VADISPLAYATTRIB_BLE_MEDIUM,
     VADISPLAYATTRIB_BLE_HIGH,
     VADISPLAYATTRIB_BLE_NONE,
 } VADisplayAttribBLEMode;
 
 #define VA_ROTATION_NONE        0x00000000
 #define VA_ROTATION_90          0x00000001
 #define VA_ROTATION_180         0x00000002
 #define VA_ROTATION_270         0x00000003
 
 #define VA_MIRROR_NONE              0x00000000
 
 #define VA_MIRROR_HORIZONTAL        0x00000001
 
 #define VA_MIRROR_VERTICAL          0x00000002
 
 #define VA_OOL_DEBLOCKING_FALSE 0x00000000
 #define VA_OOL_DEBLOCKING_TRUE  0x00000001
 
 #define VA_RENDER_MODE_UNDEFINED           0
 #define VA_RENDER_MODE_LOCAL_OVERLAY       1
 #define VA_RENDER_MODE_LOCAL_GPU           2
 #define VA_RENDER_MODE_EXTERNAL_OVERLAY    4
 #define VA_RENDER_MODE_EXTERNAL_GPU        8
 
 #define VA_RENDER_DEVICE_UNDEFINED  0
 #define VA_RENDER_DEVICE_LOCAL      1
 #define VA_RENDER_DEVICE_EXTERNAL   2
 
 typedef union _VADisplayAttribValSubDevice{
     struct{
         uint32_t current_sub_device     : 4;
         uint32_t sub_device_count       : 4;
         uint32_t reserved               : 8;
         uint32_t sub_device_mask       : 16;
     }bits;
     uint32_t value;
 }VADisplayAttribValSubDevice;
 
 typedef enum
 {
     VADisplayAttribBrightness           = 0,
     VADisplayAttribContrast             = 1,
     VADisplayAttribHue                  = 2,
     VADisplayAttribSaturation           = 3,
     /* client can specifiy a background color for the target window
      * the new feature of video conference,
      * the uncovered area of the surface is filled by this color
      * also it will blend with the decoded video color
      */
     VADisplayAttribBackgroundColor      = 4,
     /*
      * this is a gettable only attribute. For some implementations that use the
      * hardware overlay, after PutSurface is called, the surface can not be    
      * re-used until after the subsequent PutSurface call. If this is the case 
      * then the value for this attribute will be set to 1 so that the client   
      * will not attempt to re-use the surface right after returning from a call
      * to PutSurface.
      *
      * Don't use it, use flag VASurfaceDisplaying of vaQuerySurfaceStatus since
      * driver may use overlay or GPU alternatively
      */
     VADisplayAttribDirectSurface       = 5,
     VADisplayAttribRotation            = 6,     
     VADisplayAttribOutofLoopDeblock    = 7,
 
     /* PowerVR IEP Lite specific attributes */
     VADisplayAttribBLEBlackMode        = 8,
     VADisplayAttribBLEWhiteMode        = 9,
     VADisplayAttribBlueStretch         = 10,
     VADisplayAttribSkinColorCorrection = 11,
     /*
      * For type VADisplayAttribCSCMatrix, "value" field is a pointer to the color
      * conversion matrix. Each element in the matrix is float-point
      */
     VADisplayAttribCSCMatrix           = 12,
     /* specify the constant color used to blend with video surface
      * Cd = Cv*Cc*Ac + Cb *(1 - Ac) C means the constant RGB
      *      d: the final color to overwrite into the frame buffer 
      *      v: decoded video after color conversion, 
      *      c: video color specified by VADisplayAttribBlendColor
      *      b: background color of the drawable
      */
     VADisplayAttribBlendColor          = 13,
     /*
      * Indicate driver to skip painting color key or not.
      * only applicable if the render is overlay
      */
     VADisplayAttribOverlayAutoPaintColorKey   = 14,
     /*
      * customized overlay color key, the format is RGB888
      * [23:16] = Red, [15:08] = Green, [07:00] = Blue.
      */
     VADisplayAttribOverlayColorKey      = 15,
     /*
      * The hint for the implementation of vaPutSurface
      * normally, the driver could use an overlay or GPU to render the surface on the screen
      * this flag provides APP the flexibity to switch the render dynamically
      */
     VADisplayAttribRenderMode           = 16,
     /*
      * specify if vaPutSurface needs to render into specified monitors
      * one example is that one external monitor (e.g. HDMI) is enabled, 
      * but the window manager is not aware of it, and there is no associated drawable
      */
     VADisplayAttribRenderDevice        = 17,
     /*
      * specify vaPutSurface render area if there is no drawable on the monitor
      */
     VADisplayAttribRenderRect          = 18,
     /*
      * HW attribute, read/write, specify the sub device configure
      */
     VADisplayAttribSubDevice           = 19,
     /*
      * HW attribute. read only. specify whether vaCopy support on current HW
      * The value of each bit should equal to 1 << VA_EXEC_MODE_XXX to represent
      * modes of vaCopy
      */
     VADisplayAttribCopy                 = 20,
 } VADisplayAttribType;
 
 /* flags for VADisplayAttribute */
 #define VA_DISPLAY_ATTRIB_NOT_SUPPORTED 0x0000
 #define VA_DISPLAY_ATTRIB_GETTABLE      0x0001
 #define VA_DISPLAY_ATTRIB_SETTABLE      0x0002
 
 typedef struct _VADisplayAttribute
 {
     VADisplayAttribType type;
     int32_t min_value;
     int32_t max_value;
     int32_t value;      /* used by the set/get attribute functions */
 /* flags can be VA_DISPLAY_ATTRIB_GETTABLE or VA_DISPLAY_ATTRIB_SETTABLE or OR'd together */
     uint32_t flags;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VADisplayAttribute;
 
 int vaMaxNumDisplayAttributes (
     VADisplay dpy
 );
 
 VAStatus vaQueryDisplayAttributes (
     VADisplay dpy,
     VADisplayAttribute *attr_list,      /* out */
     int *num_attributes                 /* out */
 );
 
 VAStatus vaGetDisplayAttributes (
     VADisplay dpy,
     VADisplayAttribute *attr_list,      /* in/out */
     int num_attributes
 );
 
 VAStatus vaSetDisplayAttributes (
     VADisplay dpy,
     VADisplayAttribute *attr_list,
     int num_attributes
 );
 
 /****************************
  * HEVC data structures
  ****************************/
 typedef struct _VAPictureHEVC
 {
     VASurfaceID             picture_id;
     int32_t                 pic_order_cnt;
     /* described below */
     uint32_t                flags;
 
     uint32_t                va_reserved[VA_PADDING_LOW];
 } VAPictureHEVC;
 
 /* flags in VAPictureHEVC could be OR of the following */
 #define VA_PICTURE_HEVC_INVALID                 0x00000001
 
 #define VA_PICTURE_HEVC_FIELD_PIC               0x00000002
 
 #define VA_PICTURE_HEVC_BOTTOM_FIELD            0x00000004
 
 #define VA_PICTURE_HEVC_LONG_TERM_REFERENCE     0x00000008
 
 #define VA_PICTURE_HEVC_RPS_ST_CURR_BEFORE      0x00000010
 
 #define VA_PICTURE_HEVC_RPS_ST_CURR_AFTER       0x00000020
 
 #define VA_PICTURE_HEVC_RPS_LT_CURR             0x00000040
 
 typedef enum{
     VACopyObjectSurface = 0,
     VACopyObjectBuffer  = 1,
 } VACopyObjectType;
 
 typedef struct _VACopyObject {
     VACopyObjectType  obj_type;    // type of object.
     union
     {
         VASurfaceID surface_id;
         VABufferID  buffer_id;
     } object;
 
     uint32_t    va_reserved[VA_PADDING_MEDIUM];
 } VACopyObject;
 
 typedef union _VACopyOption{
     struct {
         uint32_t va_copy_sync : 2;
         uint32_t va_copy_mode : 4;
         uint32_t reserved     :26;
     }bits;
     uint32_t value;
 }VACopyOption;
 
 VAStatus vaCopy(VADisplay dpy, VACopyObject * dst, VACopyObject * src, VACopyOption option);
 
 #include <va/va_dec_hevc.h>
 #include <va/va_dec_jpeg.h>
 #include <va/va_dec_vp8.h>
 #include <va/va_dec_vp9.h>
 #include <va/va_dec_av1.h>
 #include <va/va_enc_hevc.h>
 #include <va/va_fei_hevc.h>
 #include <va/va_enc_h264.h>
 #include <va/va_enc_jpeg.h>
 #include <va/va_enc_mpeg2.h>
 #include <va/va_enc_vp8.h>
 #include <va/va_enc_vp9.h>
 #include <va/va_fei.h>
 #include <va/va_fei_h264.h>
 #include <va/va_vpp.h>
 #include <va/va_prot.h>
 
 #ifdef __cplusplus
 }
 #endif
 