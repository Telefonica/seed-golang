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
	"encoding/json"
	"fmt"
	"net/http"

	mgo "gopkg.in/mgo.v2"
	"gopkg.in/mgo.v2/bson"

	"github.com/Telefonica/govice"
	"github.com/gorilla/mux"
)

// GetUserID returns the userID included in the URL path (if available) and parsed with gorilla mux.
func GetUserID(r *http.Request) *bson.ObjectId {
	userID := mux.Vars(r)["userID"]
	if !bson.IsObjectIdHex(userID) {
		govice.GetLogger(r).Debug("userID %s is not objectID", userID)
		return nil
	}
	o := bson.ObjectIdHex(userID)
	return &o
}

func (s *Server) getDB(r *http.Request) *mgo.Database {
	return GetMongoContext(r).DB(s.Config.MongoDatabase)
}

func (s *Server) getUsersCollection(r *http.Request) *mgo.Collection {
	return s.getDB(r).C("users")
}

// CreateUser implements the creation of a user.
func (s *Server) CreateUser(w http.ResponseWriter, r *http.Request) {
	var user User
	if err := s.validator.ValidateSafeRequestBody("create-user", r, &user); err != nil {
		govice.ReplyWithError(w, r, err)
		return
	}
	userID := bson.NewObjectId()
	user.ID = &userID
	if err := s.getUsersCollection(r).Insert(&user); err != nil {
		govice.ReplyWithError(w, r, err)
		return
	}
	w.Header().Add("Location", fmt.Sprintf("%s/users/%s", s.Config.BasePath, user.ID.Hex()))
	w.WriteHeader(http.StatusCreated)
}

// GetUser forwards the request to the niji backend if the user is registered in the niji
// backend. Otherwise, it forwards the request to the nijiHome backend.
func (s *Server) GetUser(w http.ResponseWriter, r *http.Request) {
	userID := GetUserID(r)
	if userID == nil {
		govice.ReplyWithError(w, r, govice.NotFoundError)
		return
	}
	var user User
	if err := s.getUsersCollection(r).FindId(*userID).One(&user); err != nil {
		govice.ReplyWithError(w, r, err)
		return
	}
	if err := json.NewEncoder(w).Encode(&user); err != nil {
		govice.ReplyWithError(w, r, err)
		return
	}
}

// DeleteUser forwards the request to the niji backend if the user is registered in the niji
// backend. Otherwise, it forwards the request to the nijiHome backend.
func (s *Server) DeleteUser(w http.ResponseWriter, r *http.Request) {
	userID := GetUserID(r)
	if userID == nil {
		govice.ReplyWithError(w, r, govice.NotFoundError)
		return
	}
	if err := s.getUsersCollection(r).RemoveId(*userID); err != nil {
		if err == mgo.ErrNotFound {
			govice.NotFoundError.Response(w)
			return
		}
		govice.ReplyWithError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func buildPartialUpdate(user *User) bson.M {
	u := bson.M{}
	if user.Login != nil {
		u["login"] = *user.Login
	}
	if user.MSISDN != nil {
		u["msisdn"] = *user.MSISDN
	}
	if user.Name != nil {
		u["name"] = *user.Name
	}
	if user.Role != nil {
		u["role"] = *user.Role
	}
	return u
}

// UpdateUser forwards the request to the niji backend if the user is registered in the niji
// backend. Otherwise, it forwards the request to the nijiHome backend.
// If the user is migrated from niji backend to nijiHome backend (by a product change), then
// the user must be removed from the niji backend, and then created in the nijiHome backend.
func (s *Server) UpdateUser(w http.ResponseWriter, r *http.Request) {
	userID := GetUserID(r)
	if userID == nil {
		govice.ReplyWithError(w, r, govice.NotFoundError)
		return
	}
	var user User
	if err := s.validator.ValidateSafeRequestBody("update-user", r, &user); err != nil {
		govice.ReplyWithError(w, r, err)
		return
	}
	update := bson.M{"$set": buildPartialUpdate(&user)}
	if err := s.getUsersCollection(r).UpdateId(*userID, update); err != nil {
		govice.ReplyWithError(w, r, err)
		return
	}
}
