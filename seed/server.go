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
	"net/http"

	mgo "gopkg.in/mgo.v2"

	"github.com/Telefonica/govice"
	"github.com/gorilla/mux"
)

// Server manages the start and stop of the service.
type Server struct {
	*Config
	db        *mgo.Session
	server    *http.Server
	validator *govice.Validator
}

// NewServer creates a new instance of the orchestrator service.
func NewServer(config *Config, validator *govice.Validator) (*Server, error) {
	s := &Server{Config: config, validator: validator}
	return s, nil
}

// Start the orchestrator service. It also configures the proxies to niji and nijiHome.
func (s *Server) Start() error {
	if s.server != nil {
		return fmt.Errorf("Server is already started")
	}
	var err error
	if s.db, err = mgo.Dial(s.Config.MongoURL); err != nil {
		return err
	}
	s.server = &http.Server{
		Addr:    s.Address,
		Handler: s.router(),
	}
	return s.server.ListenAndServe()
}

// Stop the orchestrator service.
func (s *Server) Stop() error {
	if s.server != nil {
		s.server.Shutdown(nil)
		s.server = nil
	}
	if s.db != nil {
		s.db.Close()
		s.db = nil
	}
	return nil
}

func (s *Server) router() *mux.Router {
	r := mux.NewRouter()
	sr := r.PathPrefix(s.BasePath).Subrouter()
	sr.HandleFunc("/users", s.withMws("createUser", s.CreateUser)).Methods("POST")
	sr.HandleFunc("/users", s.withMws("notAllowed", govice.WithMethodNotAllowed("POST")))
	sr.HandleFunc("/users/{userID}", s.withMws("getUser", s.GetUser)).Methods("GET")
	sr.HandleFunc("/users/{userID}", s.withMws("deleteUser", s.DeleteUser)).Methods("DELETE")
	sr.HandleFunc("/users/{userID}", s.withMws("updateUser", s.UpdateUser)).Methods("PATCH")
	sr.HandleFunc("/users/{userID}", s.withMws("notAllowed", govice.WithMethodNotAllowed("GET", "DELETE", "PATCH")))
	r.NotFoundHandler = http.HandlerFunc(s.withMws("notFound", govice.WithNotFound()))
	return r
}
