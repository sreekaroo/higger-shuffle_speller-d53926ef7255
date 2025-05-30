CMAKE_MINIMUM_REQUIRED(VERSION 2.8.8)

PROJECT(DAQGUSBAMP)

# Set Build type: Release
IF(NOT CMAKE_BUILD_TYPE)
  SET(CMAKE_BUILD_TYPE "RELEASE")
ENDIF()

ADD_DEFINITIONS(-D_AFXDLL)
SET(CMAKE_MFC_FLAG 2)

#SET(CMAKE_CXX_FLAGS_RELEASE "/MT")
#SET(CMAKE_CXX_FLAGS_DEBUG "/MTd")

# Set parameters
# SET(BUILD_SHARED_LIBS ON)
# SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC")

# Begin: necessary code for library relative path
SET(CMAKE_SKIP_BUILD_RPATH FALSE)
SET(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE) 
SET(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib")
SET(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
LIST(FIND CMAKE_PLATFORM_IMPLICIT_LINK_DIRECTORIES "${CMAKE_INSTALL_PREFIX}/lib" isSystemDir)
IF("${isSystemDir}" STREQUAL "-1")
   SET(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/lib")
ENDIF("${isSystemDir}" STREQUAL "-1")
# End: necessary code for library relative path

# Compile source
SET(GTEC_LIBRARY_DIR "C:\\Program Files\\gtec\\gUSBampCAPI\\API\\x64" CACHE FILEPATH "Location of gtec library")
SET(GTEC_LIBRARY_NAME "gUSBamp" CACHE FILEPATH "Name of gtec library")

SET(DAQGUSBAMP_LINK_DIR ${CMAKE_CURRENT_SOURCE_DIR}/lib)    
SET(DAQGUSBAMP_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src)    
SET(DAQGUSBAMP_TEST_DIR ${CMAKE_CURRENT_SOURCE_DIR}/test)    
SET(DAQGUSBAMP_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/inc)

INCLUDE_DIRECTORIES(${GTEC_LIBRARY_DIR})
INCLUDE_DIRECTORIES(${DAQGUSBAMP_INCLUDE_DIR})

SET(SRC_FILES
  ${DAQGUSBAMP_SOURCE_DIR}/DAQgUSBamp.cpp
  ${DAQGUSBAMP_SOURCE_DIR}/stdafx.cpp
  )

SET(TEST_SRC_FILES
  ${DAQGUSBAMP_TEST_DIR}/DAQgUSBAmpTest.cpp
  )
  
ADD_LIBRARY(DAQgUSBAmp STATIC ${SRC_FILES})
TARGET_LINK_LIBRARIES(DAQgUSBAmp ${GTEC_LIBRARY_DIR}\\${GTEC_LIBRARY_NAME}.lib)
#TARGET_LINK_LIBRARIES(DaqTobiiEyeX ${DAQGUSBAMP_LINK_DIR}/x64/TobiiGazeCore64.lib)

INSTALL(TARGETS DAQgUSBAmp DESTINATION lib)

ADD_EXECUTABLE(DAQgUSBAmpTest ${TEST_SRC_FILES})
TARGET_LINK_LIBRARIES(DAQgUSBAmpTest DAQgUSBAmp)
TARGET_LINK_LIBRARIES(DAQgUSBAmpTest ${GTEC_LIBRARY_DIR}\\${GTEC_LIBRARY_NAME}.lib)

INSTALL(TARGETS DAQgUSBAmpTest DESTINATION bin)

