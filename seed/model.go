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

import "gopkg.in/mgo.v2/bson"

// User represents a user of the service.
type User struct {
	ID     *bson.ObjectId `json:"id" bson:"_id"`
	Login  *string        `json:"login" bson:"login"`
	Name   *string        `json:"name" bson:"name"`
	MSISDN *string        `json:"msisdn" bson:"msisdn"`
	Role   *string        `json:"role,omitempty" bson:"role,omitempty"`
}
