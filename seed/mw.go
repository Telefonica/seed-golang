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
	"context"
	"net/http"

	mgo "gopkg.in/mgo.v2"

	"github.com/Telefonica/govice"
)

// ServiceName is the service name for logging purposes.
const ServiceName = "seed"

type mongoContextKey string

// MongoContextKey is a unique key to store a mongodb session in the golang context.
var MongoContextKey = mongoContextKey("mongo")

// WithMongo builds a middleware to pass a copy of the mongo session in the context of each HTTP request.
func WithMongo(s *mgo.Session) func(http.HandlerFunc) http.HandlerFunc {
	return func(next http.HandlerFunc) http.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request) {
			session := s.Copy()
			defer session.Close()
			req := r.WithContext(context.WithValue(r.Context(), MongoContextKey, session))
			next.ServeHTTP(w, req)
		}
	}
}

func (s *Server) withMws(op string, next http.HandlerFunc) http.HandlerFunc {
	logContext := &govice.LogContext{
		Service:   ServiceName,
		Operation: op,
	}
	withLogContext := govice.WithLogContext(logContext)
	withMongo := WithMongo(s.db)
	return withLogContext(govice.WithLog(withMongo(next)))
}

// GetMongoContext returns a mongo session from the context of the request.
// Note that the session is saved in the context by the middleware WithMongo.
func GetMongoContext(r *http.Request) *mgo.Session {
	return r.Context().Value(MongoContextKey).(*mgo.Session)
}
