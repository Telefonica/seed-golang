/**
 * @license
 * Copyright 2017 Telefónica Investigación y Desarrollo, S.A.U
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package main

import (
	"encoding/json"
	"flag"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/Telefonica/govice"
	"github.com/Telefonica/seed-golang/seed"
)

func main() {
	// Prepare logger
	time.Local = time.UTC
	logContext := govice.LogContext{
		Service:   seed.ServiceName,
		Operation: "init",
	}
	logger := govice.NewLogger()
	logger.SetLogContext(&logContext)
	alarmContext := &govice.LogContext{Alarm: seed.AlarmInit}

	// Prepare the configuration
	cfgFile := flag.String("config", "./config.json", "path to config file")
	flag.Parse()
	var cfg seed.Config
	if err := govice.GetConfig(*cfgFile, &cfg); err != nil {
		logger.FatalC(alarmContext, "Bad configuration with file '%s'. %s", *cfgFile, err)
		os.Exit(1)
	}
	logger.SetLevel(cfg.LogLevel)
	govice.SetDefaultLogLevel(cfg.LogLevel)

	// Log the configuration
	if configBytes, err := json.Marshal(cfg); err == nil {
		logger.Info("Configuration: %s", string(configBytes))
	}

	// Create the validator and validate the configuration
	validator := govice.NewValidator()
	if err := validator.LoadSchemas("schemas"); err != nil {
		logger.FatalC(alarmContext, "Error loading JSON schemas for validator. %s", err)
		os.Exit(1)
	}
	if err := validator.ValidateConfig("config", &cfg); err != nil {
		logger.FatalC(alarmContext, "Bad configuration according to JSON schema. %s", err)
		os.Exit(1)
	}

	server, err := seed.NewServer(&cfg, validator)
	if err != nil {
		logger.FatalC(alarmContext, "Error creating server. %s", err)
		os.Exit(1)
	}

	// Capture signals to stop the server
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt, syscall.SIGHUP, syscall.SIGTERM)
	go func() {
		for sig := range c {
			logger.Warn("Captured signal %s. Stopping server", sig)
			if err := server.Stop(); err != nil {
				logger.Error("Error stopping server. %s", err)
			}
			os.Exit(0)
		}
	}()

	// Start the server
	logger.Info("Starting server at %s", cfg.Address)
	if err := server.Start(); err != nil {
		logger.FatalC(alarmContext, "Error starting server. %s", err)
		os.Exit(1)
	}
}
