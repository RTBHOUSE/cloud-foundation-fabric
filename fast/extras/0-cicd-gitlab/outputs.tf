/**
 * Copyright 2024 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

output "clone" {
  description = "Clone projects commands."
  value = {
    for k, v in var.projects :
    k => "ssh://git@${var.gitlab_config.hostname}:${var.gitlab_config.ssh_port}/${(var.gitlab_config.saas_group != "" ? "${var.gitlab_config.saas_group}/${v.group}" : "${v.group}")}/${k}.git"
  }
}
