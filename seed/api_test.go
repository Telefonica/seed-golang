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

package seed

import (
	"fmt"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/Telefonica/govice"
)

var defaultServer = server()

func validator() *govice.Validator {
	validator := govice.NewValidator()
	err := validator.LoadSchemas("cmd/seed/schemas")
	fmt.Printf("Error validator: %s", err)
	return validator
}

func server() *Server {
	c := &Config{
		Address:       ":9000",
		BasePath:      "/seed",
		LogLevel:      "INFO",
		MongoURL:      "127.0.0.1",
		MongoDatabase: "seed_test",
	}
	v := validator()
	s, _ := NewServer(c, v)
	go s.Start()
	// Wait until server is started
	for i := 0; i < 100; i++ {
		time.Sleep(100 * time.Millisecond)
		if s.server != nil {
			break
		}
	}
	return s
}

func TestCreateUser(t *testing.T) {
	tests := []struct {
		body         string
		expectedCode int
	}{
		{`{"login": "uid1", "name": "Test User", "msisdn": "34123456789", "role": "user"}`, 201},
		{`{"login": "uid1", "name": "Test User", "msisdn": "34123456789"}`, 201},
		{`{"login": "uid1", "name": "Test User", "msisdn": "34123456789", "role": "invalid"}`, 400},
		{`{"name": "Test User", "msisdn": "34123456789", "role": "user"}`, 400},
	}
	for _, test := range tests {
		body := strings.NewReader(test.body)
		r := httptest.NewRequest("POST", "/seed/users", body)
		r.Header.Add("Content-Type", "application/json")
		w := httptest.NewRecorder()
		defaultServer.router().ServeHTTP(w, r)
		if w.Code != test.expectedCode {
			t.Errorf("Wrong status code. Got %v, expected %v", w.Code, test.expectedCode)
		}
	}
}
