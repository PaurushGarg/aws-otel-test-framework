package com.amazon.aoc.models;

import lombok.Data;

import java.util.List;

@Data
public class HostmetricsContext {
  // hostmetrics receiver testcase related context
  private List<String> hostId;

  private List<String> cpuNames;
  private List<String> diskDevices;
  private List<String> filesystemDevices;
  private List<String> mountpointModes;
  private List<String> mountpoints;
  private List<String> networkInterfaces;

  private List<String> processCommand;
  private List<String> processCommandLine;
  private List<String> processExecutableName;
  private List<String> processExecutablePath;
}